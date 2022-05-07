INSERT INTO m2_invoices (number, user_id, status, status_changed, created_at, updated_at, issue_date, period_start, period_end, due_date, timezone, client_name, client_details1, client_details2, client_details3, client_details4, client_details5, client_details6, currency, currency_exchange_rate, total_amount, total_amount_with_taxes, comment, mailed_to_user, notified_admin, notified_manager) VALUES
('number1', 4, 'In process', '2009-03-22 09:25:00', '2009-03-20 00:00:00', '2009-03-21 01:01:01', '2013-03-20 01:01:01', '2009-03-21 00:00:00', '2009-03-25 23:59:59', '2014-03-20 23:59:59', 'Vilnius', 'accountant', 'California 12 - 55', 'California City', '65497', 'United States', '225', '23232323', 'usd', 1.00, 11.11, 11.99, 'Pirmas komentaras', 1, 0, 0),
('number22', 3, 'Sent through Email', '2010-03-22 09:25:00', '20010-03-20 00:00:00', '2010-03-21 02:02:02', '2012-03-20 01:01:01', '2010-03-21 00:00:00', '2010-03-25 23:59:59', '2014-03-21 23:59:59', 'Uganda', 'reseller', 'Street 12 - 55', 'Uganda City', '88888', 'Africa', '245', '989898', 'eur', 2.00, 22.22, 22.99, 'Antras komentaras', 0, 1, 0),
('number3', 3, 'Sent Manually', '2011-03-22 09:25:00', '2011-03-20 00:00:00', '2011-03-21 01:01:01', '2013-03-20 03:03:03', '2011-03-21 00:00:00', '2011-03-25 23:59:59', '2012-03-20 23:59:59', 'London', 'reseller', 'Some street 12 - 55', 'London', '9542', 'United Kingdom', '125', '77777', 'usd', 1.00, 33.33, 33.99, 'Trecias komentaras', 0, 0, 1),
('number444', 2, 'Accepted', '2014-03-22 09:25:00', '2014-03-20 00:00:00', '2014-03-21 10:10:10', '2014-03-20 04:04:04', '2014-03-21 00:00:00', '2014-03-25 23:59:59', '2015-03-20 23:59:59', 'Kaunas', 'user_admin', 'Roger 12 - 55', 'Kaunas', '545552', 'Lithuania', '123', '8848484', 'ltl', 0.5, 44.44, 44.99, 'Ketvirtas ilgesnis už kitus komentaras', 1, 1, 0),
('number5', 5, 'Protested', '2010-03-22 09:25:00', '2009-03-20 00:00:00', '2009-03-21 01:01:01', '2013-03-20 05:05:05', '2009-03-21 00:00:00', '2009-03-25 23:59:59', '2014-03-20 23:59:59', 'Dubaj', 'user_reseller', 'Good st. 12 - 55', 'Dubaj', '55555', 'Emirates', '88', '0000111', 'eur', 3.00, 55.55, 55.99, '', 1, 0, 1),
('number66', 5, 'In process', '2014-01-30 09:25:00', '2014-01-30 00:00:00', '2014-01-30 22:02:02', '2014-01-30 06:06:06', '2014-01-30 00:00:00', '2014-01-30 23:59:59', '2014-01-30 23:59:59', 'Vilnius', 'user_reseller', 'Glezinkelio 12 - 55', 'Vilnius', '123654', 'Lithuania', '123', '23232323', 'usd', 1.00, 66.66, 66.99, 'Šeštas komentaras', 1, 1, 1);

INSERT INTO m2_invoice_lines (m2_invoice_id, destination, name, rate, calls, total_time, price) VALUES
(1, 35567, 'Albania mobile', 3.7, 10, 854, 1.1),
(1, 39377, 'Italy mobile-Vodafone', 3.7, 22, 78, 1.2),
(1, 21695, 'Tunisia mobile-Tuntel', 4.2, 2, 85, 0.1),
(2, 417745, 'Switzerland mobile-Swisscom', 3.7, 5, 9, 10.1);

UPDATE currencies SET exchange_rate = 0.5 WHERE name = 'EUR';
UPDATE currencies SET exchange_rate = 1.5 WHERE name = 'LTL';
UPDATE `currencies` SET `active` = 1 WHERE name = 'LTL';
