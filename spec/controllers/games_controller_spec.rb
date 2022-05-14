# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe '#create' do
    context 'when registered user' do
      before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

      # юзер может создать новую игру
      it 'creates game' do
        # сперва накидаем вопросов, из чего собирать новую игру
        generate_questions(15)

        post :create
        game = assigns(:game) # вытаскиваем из контроллера поле @game

        # проверяем состояние этой игры
        expect(game.finished?).to be_falsey
        expect(game.user).to eq(user)
        # и редирект на страницу этой игры
        expect(response).to redirect_to(game_path(game))
        expect(flash[:notice]).to be
      end

      # юзер пытается создать новую игру, не закончив старую
      it 'try to create second game' do
        # убедились что есть игра в работе
        expect(game_w_questions.finished?).to be_falsey

        # отправляем запрос на создание, убеждаемся что новых Game не создалось
        expect { post :create }.to change(Game, :count).by(0)

        game = assigns(:game) # вытаскиваем из контроллера поле @game
        expect(game).to be_nil

        # и редирект на страницу старой игры
        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end

    context 'when anonymous' do
      it 'kick from #create' do
        post :create, id: game_w_questions.id
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end

    end
  end
  describe '#show' do
    context 'when registered user' do
      before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in
      # юзер видит свою игру
      it '#show game' do
        get :show, id: game_w_questions.id
        game = assigns(:game) # вытаскиваем из контроллера поле @game
        expect(game.finished?).to be_falsey
        expect(game.user).to eq(user)

        expect(response.status).to eq(200) # должен быть ответ HTTP 200
        expect(response).to render_template('show') # и отрендерить шаблон show
      end

      # проверка, что пользовтеля посылают из чужой игры
      it '#kick from alien game' do
        # создаем новую игру, юзер не прописан, будет создан фабрикой новый
        alien_game = FactoryBot.create(:game_with_questions)

        # пробуем зайти на эту игру текущий залогиненным user
        get :show, id: alien_game.id

        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context 'when anonymous' do
      # Анонимный (незалогиненный) посетитель не может вызвать действие
      it 'kick from #show' do
        get :show, id: game_w_questions.id
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end

    end
  end

  describe '#answer' do
    context 'when registered user' do
      # перед каждым тестом в группе
      before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in
      # юзер отвечает на игру корректно - игра продолжается
      it 'and answers correct' do
        # передаем параметр params[:letter]
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
        game = assigns(:game)

        expect(game.finished?).to be false
        expect(game.current_level).to be > 0
        expect(response).to redirect_to(game_path(game))
        expect(flash.empty?).to be true # удачный ответ не заполняет flash
      end

      # юзер не отвечает корректно -- игра завершается
      it 'and answers is not correct' do
        correct_answer = game_w_questions.current_game_question.correct_answer_key
        not_correct_answer = (%w[a b c d] - [correct_answer]).sample
        # передаем параметр params[:letter]
        put :answer, id: game_w_questions.id, letter: not_correct_answer
        game = assigns(:game)

        expect(game.finished?).to be true
        expect(game.current_level).to be_zero
        expect(response).to redirect_to(user_path(user))
        expect(flash.empty?).to be false
        expect(flash[:alert]).to be
        expect(flash[:alert]).to be_a(String)
        expect(flash[:alert]).to match("Правильный ответ: #{game_w_questions.current_game_question.correct_answer}. Игра закончена, ваш приз 0")
        expect(I18n.t('controllers.games.bad_answer',
                      answer: game_w_questions.current_game_question.correct_answer_key,
                      prize: game_w_questions.prize))
          .to match("Правильный ответ: d. Игра закончена, ваш приз 0")
      end
    end

    context 'when anonymous' do
      it 'kick from #answer' do
        put :create, id: game_w_questions.id
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end
  end

  describe '#take_money' do
    # группа тестов на экшены контроллера, доступных залогиненным юзерам
    context 'when registered user' do
      before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in
      # юзер берет деньги
      it 'takes money' do
        # вручную поднимем уровень вопроса до выигрыша 200
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money, id: game_w_questions.id
        game = assigns(:game)
        expect(game.finished?).to be_truthy
        expect(game.prize).to eq(200)

        # пользователь изменился в базе, надо в коде перезагрузить!
        user.reload
        expect(user.balance).to eq(200)

        expect(response).to redirect_to(user_path(user))
        expect(flash[:warning]).to be
      end
    end
    context 'when anonymous' do
      it 'kick from #take_money' do
        put :create, id: game_w_questions.id
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end
  end
end
