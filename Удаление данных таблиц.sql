-- Отключаем все ограничения (включая внешние ключи)
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'

-- Удаляем данные из указанных таблиц (TRUNCATE быстрее, но не работает при наличии FK)
EXEC sp_MSforeachtable 'DELETE FROM Схема.Таблица'

-- Включаем ограничения обратно
EXEC sp_MSforeachtable 'ALTER TABLE ? CHECK CONSTRAINT ALL'