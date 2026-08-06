class PagesController < ApplicationController
  #
  # Главная страница.
  # Залогиненный пользователь при ПЕРВОМ открытии сайта/ПВА в текущей сессии
  # сразу переводится на карту POI (/pois). Далее навигация свободная — он может
  # перейти на любую страницу, включая главную (без повторных скачков).
  # Гость видит главную (лендинг); карта /pois доступна гостю в режиме просмотра
  # (маркеры/тултипы видимы, детали и взаимодействие — только после авторизации).
  #
  def index
    return unless user_signed_in?

    unless session[:redirected_to_map]
      session[:redirected_to_map] = true
      redirect_to pois_path
    end
  end
end
