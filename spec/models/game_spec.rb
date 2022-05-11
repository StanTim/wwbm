# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)

      # Ранее текущий вопрос стал предыдущим
      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey

    end

    it 'take money by user is correct' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end

    it 'take_money! finishes the game' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end

    describe '.previous_level' do
      # Предыдущий уровень стал на один уровень ниже
      it 'previous level should be one step down' do
        expect(game_w_questions.previous_level).to eq(-1)
      end
    end

    describe '.current_game_question' do
      # Следующий вопрос стал текущим
      it 'next question should be current' do
        expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[0])
      end
    end

    describe '#answer_current_question!' do
      let(:right_answer) { game_w_questions.current_game_question.correct_answer_key }
      let(:wrong_answer) { (%w(a b c d) - [right_answer]).sample }

      # Если пользователь дал верный ответ.
      context 'when right answer' do
        it 'should return true' do
          expect(game_w_questions.answer_current_question!(right_answer)).to be true
        end

        it 'should change game level up' do
          l = game_w_questions.current_level
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.current_level }.from(l).to(l + 1)
        end

        it 'should change status' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to_not change { game_w_questions.status }
        end
      end

      # Если пользователь дал неправильный ответ.
      context 'when answer is wrong' do
        it 'should be change is_failed to true' do
          expect { game_w_questions.answer_current_question!(wrong_answer) }
            .to change { game_w_questions.is_failed }.to(true)
        end

        it 'should be false' do
          expect(game_w_questions.answer_current_question!(wrong_answer)).to be false
        end

        it 'should change status :fail' do
          expect { game_w_questions.answer_current_question!(wrong_answer) }
            .to change { game_w_questions.status }.from(:in_progress).to(:fail)
        end
      end

      # Правильный ответ на финальный вопрос.
      context 'when final question answer' do
        before { game_w_questions.current_level = Question::QUESTION_LEVELS.max }

        it 'should be true' do
          expect(game_w_questions.answer_current_question!(right_answer)).to be true
        end

        it 'should change game prize' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.prize }
        end

        it 'should change game prize to max value' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.prize }.to(Game::PRIZES.max)
        end

        it 'should be change finished_at' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.finished_at }
        end

        it 'should change status :won' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.status }.from(:in_progress).to(:won)
        end
      end

      # Правильный ответ по завершении времени.
      context 'when timeout' do
        before { game_w_questions.created_at = (Game::TIME_LIMIT + 1.second).ago }
        it 'should be false' do
          expect(game_w_questions.answer_current_question!(right_answer)).to be false
        end

        it 'should change status :timeout' do
          expect { game_w_questions.answer_current_question!(right_answer) }
            .to change { game_w_questions.status }.from(:in_progress).to(:timeout)
        end
      end
    end
  end
end
