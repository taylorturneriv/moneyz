CREATE TABLE `TRANSACTION` (
  `transaction_number` int(11) DEFAULT NULL,
  `timestamp_key` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `TRID` varchar(255) DEFAULT NULL,
  `memo` varchar(255) DEFAULT NULL,
  `debit` varchar(255) DEFAULT NULL,
  `credit` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;