require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe '#create' do
    context 'when registered user' do
      before do
        # логиним юзера user с помощью спец. Devise метода sign_in
        sign_in user
        # накидаем вопросов, из чего собирать новую игру
        generate_questions(15)
        post :create
      end

      let(:game) { assigns(:game) } # вытаскиваем из контроллера поле @game

      context 'create new game' do

        # юзер может создать новую игру
        it 'should create game' do
          # проверяем состояние этой игры
          expect(game.finished?).to be false
        end

        # игра принадлежит юзеру
        it 'should be a game owner' do
          expect(game.user).to eq(user)
        end

        # и редирект на страницу этой игры
        it 'should redirect to game page' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'should show notice' do
          expect(flash[:notice]).to be
        end
      end

      # вытаскиваем из контроллера поле @game
      let(:game1) { assigns(:game1) }

      # юзер пытается создать новую игру, не закончив старую
      context 'trying to create one more game' do

        # отправляем запрос на создание, убеждаемся что новых Game не создалось
        it 'should be nil' do
          expect(game1).to be_nil
        end

        it 'should be false' do
          # убедились что есть игра в работе
          expect(game_w_questions.finished?).to be false
        end

        it 'should not change game quantity' do
          expect { post :create }.to change(Game, :count).by(0)
        end

        # и редирект на страницу старой игры
        it 'should redirect to first game' do
          expect(response).to redirect_to(game_path(game))
        end

        # предупреждение о недопустимости более одной игры
        it 'flash alert should to be' do
          expect(flash[:notice]).to be
        end
      end
    end

    context 'when anonymous' do
      before { post :create, id: game_w_questions.id }

      # статус не 200 ОК
      it 'kick from #create' do
        expect(response.status).not_to eq(200)
      end

      # devise должен отправить на логин
      it 'should redirect to autorization' do
        expect(response).to redirect_to(new_user_session_path)
      end

      # во flash должен быть прописана ошибка
      it 'should be alert' do
        expect(flash[:alert]).to be
      end
    end
  end

  describe '#show' do
    context 'when registered user' do
      before do
        # логиним юзера user с помощью спец. Devise метода sign_in
        sign_in user

        # юзер видит свою игру
        get :show, id: game_w_questions.id
      end

      # вытаскиваем из контроллера поле @game
      let(:game) { assigns(:game) }

      it 'should be false' do
        expect(game.finished?).to be false
      end

      it 'should equal user' do
        expect(game.user).to eq(user)
      end

      # должен быть ответ HTTP 200
      it 'should return 200' do
        expect(response.status).to eq(200)
      end

      # и отрендерить шаблон show
      it 'should render template' do
        expect(response).to render_template('show')
      end

      # проверка, что пользовтеля посылают из чужой игры
      context '#kick from alien game' do
        before do
          sign_in user
          # создаем новую игру, юзер не прописан, будет создан фабрикой новый
          alien_game = FactoryBot.create(:game_with_questions)
          # пробуем зайти на эту игру текущий залогиненным user
          get :show, id: alien_game.id
        end

        # статус не 200 ОК
        it 'should not equal 200' do
          expect(response.status).not_to eq(200)
        end

        it 'should redirect to root path' do
          expect(response).to redirect_to root_path
        end

        # во flash должен быть прописана ошибка
        it 'should be flash alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  context 'when anonymous' do
    # Анонимный (незалогиненный) посетитель не может вызвать действие
    before do
      get :show, id: game_w_questions.id
    end

    # статус не 200 ОК
    it 'should not be HTTP 200 OK' do
      expect(response.status).not_to eq(200)
    end

    # devise должен отправить на логин
    it 'should redirect to user authorization' do
      expect(response).to redirect_to(new_user_session_path)
    end

    # во flash должен быть прописана ошибка
    it 'should be flash alert' do
      expect(flash[:alert]).to be
    end
  end

  describe '#answer' do
    context 'when registered user' do
      # перед каждым тестом в группе
      before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in
      # юзер отвечает на игру корректно - игра продолжается
      context 'and answers correct' do
        before do
          # передаем параметр params[:letter]
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
        end

        let(:game) { assigns(:game) }

        it 'should be false' do
          expect(game.finished?).to be false
        end

        it 'should be more then zero' do
          expect(game.current_level).to be > 0
        end

        it 'should redirect to game page' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'should be true' do
          expect(flash.empty?).to be true # удачный ответ не заполняет flash
        end
      end

      # юзер не отвечает корректно -- игра завершается
      context 'and answers is not correct' do
        before do
          correct_answer = game_w_questions.current_game_question.correct_answer_key
          not_correct_answer = (%w[a b c d] - [correct_answer]).sample
          # передаем параметр params[:letter]
          put :answer, id: game_w_questions.id, letter: not_correct_answer
        end

        let(:game) { assigns(:game) }
        it 'should be true' do
          expect(game.finished?).to be true
        end

        it 'should be zero' do
          expect(game.current_level).to be_zero
        end

        it 'should redirect to user page' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'should be false' do
          expect(flash.empty?).to be false
        end

        it 'should be flash alert' do
          expect(flash[:alert]).to be
        end

        it 'should be a String' do
          expect(flash[:alert]).to be_a(String)
        end

        it 'should be match right answer' do
          expect(flash[:alert]).to match("Правильный ответ: #{game_w_questions.current_game_question.correct_answer}. Игра закончена, ваш приз 0")
        end

        it 'should match right answer ' do
          expect(I18n.t(
            'controllers.games.bad_answer',
            answer: game_w_questions.current_game_question.correct_answer_key,
            prize: game_w_questions.prize)
          ).to match("Правильный ответ: d. Игра закончена, ваш приз 0")
        end
      end
    end

    context 'when anonymous' do
      before do
        put :create, id: game_w_questions.id
      end

      it 'kick from #answer' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      # devise должен отправить на логин
      it 'should redirect' do
        expect(response).to redirect_to(new_user_session_path)
      end

      # во flash должен быть прописана ошибка
      it 'should ' do
        expect(flash[:alert]).to be
      end
    end

    describe '#take_money' do
      # группа тестов на экшены контроллера, доступных залогиненным юзерам
      context 'when registered user' do
        before do
          # логиним юзера user с помощью спец. Devise метода sign_in
          sign_in user
          game_w_questions.update_attribute(:current_level, 2)
          put :take_money, id: game_w_questions.id
          # пользователь изменился в базе, надо в коде перезагрузить!
          user.reload
        end

        let(:game) { assigns(:game) }

        # юзер берет деньги
        it 'should be true' do
          # вручную поднимем уровень вопроса до выигрыша 200
          expect(game.finished?).to be true
        end

        it 'should return 200' do
          expect(game.prize).to eq(200)
        end

        it 'should equal 200 rubles' do
          expect(user.balance).to eq(200)
        end

        it 'should redirect to user page' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'should be flash warning' do
          expect(flash[:warning]).to be
        end
      end
    end

    context 'when anonymous' do
      before do
        put :create, id: game_w_questions.id
      end

      # статус не 200 ОК
      it 'should return NOT http 200 ok' do
        expect(response.status).not_to eq(200)
      end

      it 'should redirect to new user registration path' do
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      end

      # во flash должен быть прописана ошибка
      it 'should be flash alert' do
        expect(flash[:alert]).to be
      end
    end
  end
end
