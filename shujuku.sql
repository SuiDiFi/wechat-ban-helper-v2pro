-- MySQL dump 10.13  Distrib 5.7.44, for Linux (x86_64)
--
-- Host: localhost    Database: airuan
-- ------------------------------------------------------
-- Server version	5.7.44-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activation_codes`
--

DROP TABLE IF EXISTS `activation_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activation_codes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(32) NOT NULL,
  `max_uses` int(11) NOT NULL DEFAULT '1',
  `used_count` int(11) NOT NULL DEFAULT '0',
  `status` enum('active','expired','disabled') DEFAULT 'active',
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  KEY `created_by` (`created_by`),
  KEY `idx_activation_codes_code` (`code`),
  KEY `idx_activation_codes_status` (`status`),
  CONSTRAINT `activation_codes_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `activation_codes`
--

LOCK TABLES `activation_codes` WRITE;
/*!40000 ALTER TABLE `activation_codes` DISABLE KEYS */;
INSERT INTO `activation_codes` VALUES (1,'DEMO-2026-TEST',50,22,'active',NULL,'2026-05-26 12:00:55',NULL),(2,'DM2BECXOU3CEYZ8N',1,0,'active',1,'2026-05-26 12:12:45',NULL),(3,'3NCK5D0AJWX2H3VK',1,0,'active',1,'2026-05-26 12:12:45',NULL),(4,'ZCFFC9FLY0DXZAPQ',1,0,'active',1,'2026-05-26 12:12:45',NULL),(5,'FAJT8OA0BO4K8XS9',1,0,'active',1,'2026-05-26 12:12:45',NULL),(6,'QOYT3OW3E1GFH5TJ',1,0,'active',1,'2026-05-26 12:12:45',NULL),(7,'4XY0JXJVM77YDIXV',1,0,'active',1,'2026-05-26 12:12:45',NULL),(8,'2RERPQ3WPSWTTP0U',1,0,'active',1,'2026-05-26 12:12:45',NULL),(9,'YWUYKC1PDLZ9VECJ',1,0,'active',1,'2026-05-26 12:12:45',NULL),(10,'LRLIQLCSO31MD90B',1,0,'active',1,'2026-05-26 12:12:45',NULL),(11,'LT2RAJZSTLULZU6O',1,0,'active',1,'2026-05-26 12:12:45',NULL),(12,'7H7A1BKKODG0JMGB',1,1,'expired',1,'2026-05-31 16:32:50',NULL),(13,'CB6KFFPQFRAL921X',1,1,'expired',1,'2026-05-31 16:42:20','2028-11-11 03:11:00'),(14,'N3K1J3BOSMMY4VMB',1,1,'expired',1,'2026-05-31 17:58:02','2026-11-11 03:11:00'),(15,'1QOM4EH7BULP2ZWD',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(16,'JLNWRAWTUSORD041',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(17,'OPIW3019WLOCX83H',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(18,'CV4HGJF14KNE7QCT',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(19,'FJDI1KELWC4ZFO79',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(20,'H5HIE56CUTYGYHI6',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(21,'0QAMV4UCICQJXRCM',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(22,'YI439HV5XP3PQON6',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(23,'R6IE5A5BBUOBJ0NH',1,0,'active',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(24,'WBWVDUQP8ASN90T1',1,1,'expired',1,'2026-05-31 18:25:30','2028-05-31 18:25:00'),(25,'33J2I20Y70OZKMYQ',3,2,'active',1,'2026-05-31 18:53:26','2026-06-01 18:53:00'),(26,'C4M8QTFWXP6JDCSK',1,1,'expired',1,'2026-05-31 21:05:14',NULL);
/*!40000 ALTER TABLE `activation_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_logs`
--

DROP TABLE IF EXISTS `task_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `task_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_id` int(11) NOT NULL,
  `account_id` varchar(50) NOT NULL,
  `account_name` varchar(100) DEFAULT NULL,
  `action` varchar(100) DEFAULT NULL,
  `status` enum('pending','success','failed') DEFAULT 'pending',
  `error_message` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_task_logs_task_id` (`task_id`),
  CONSTRAINT `task_logs_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_logs`
--

LOCK TABLES `task_logs` WRITE;
/*!40000 ALTER TABLE `task_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `task_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tasks`
--

DROP TABLE IF EXISTS `tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `target` varchar(100) NOT NULL,
  `report_type` varchar(50) NOT NULL,
  `account_count` int(11) NOT NULL,
  `activation_code_id` int(11) DEFAULT NULL,
  `status` enum('pending','running','completed','failed') DEFAULT 'pending',
  `success_count` int(11) DEFAULT '0',
  `fail_count` int(11) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_tasks_activation_code` (`activation_code_id`),
  KEY `idx_tasks_status` (`status`),
  CONSTRAINT `tasks_ibfk_1` FOREIGN KEY (`activation_code_id`) REFERENCES `activation_codes` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'132323232323','诈骗欺诈',12,13,'pending',0,0,'2026-05-31 16:43:10',NULL),(2,'132323232323','诈骗欺诈',12,1,'pending',0,0,'2026-05-31 16:43:46',NULL),(3,'12341241','诈骗欺诈',12,12,'pending',0,0,'2026-05-31 16:51:49',NULL),(4,'124131','诈骗欺诈',12,14,'completed',10,2,'2026-05-31 17:58:19','2026-05-31 17:58:32'),(5,'1586','诈骗欺诈',12,1,'completed',10,2,'2026-05-31 18:10:26','2026-05-31 18:10:35'),(6,'1586','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 18:10:38','2026-05-31 18:10:48'),(7,'1263688','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 18:13:11','2026-05-31 18:13:20'),(8,'125666','诈骗欺诈',24,1,'completed',19,5,'2026-05-31 18:17:47','2026-05-31 18:18:03'),(9,'5578954556','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 18:50:21','2026-05-31 18:50:30'),(10,'5578954556','骚扰辱骂',12,1,'completed',9,3,'2026-05-31 18:50:57','2026-05-31 18:51:06'),(11,'2316565','诈骗欺诈',12,25,'completed',9,3,'2026-05-31 19:32:55','2026-05-31 19:33:05'),(12,'7894','诈骗欺诈',12,25,'completed',10,2,'2026-05-31 19:37:41','2026-05-31 19:37:50'),(13,'Hxjsjs','诈骗欺诈',12,24,'completed',9,3,'2026-05-31 19:38:18','2026-05-31 19:38:26'),(14,'Fghj','诈骗欺诈',24,1,'completed',16,8,'2026-05-31 19:41:52','2026-05-31 19:42:08'),(15,'Fghj','诈骗欺诈',24,1,'completed',18,6,'2026-05-31 19:44:06','2026-05-31 19:44:23'),(16,'Fghj','诈骗欺诈',24,1,'completed',18,6,'2026-05-31 19:48:25','2026-05-31 19:48:40'),(17,'sdfasd','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 19:48:51','2026-05-31 19:49:03'),(18,'Sjsj','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 19:50:29','2026-05-31 19:50:38'),(19,'j d j s j s','诈骗欺诈',12,1,'completed',10,2,'2026-05-31 19:52:10','2026-05-31 19:52:20'),(20,'jdjdjd','诈骗欺诈',12,1,'completed',8,4,'2026-05-31 19:52:39','2026-05-31 19:52:48'),(21,'12314','诈骗欺诈',12,1,'completed',8,4,'2026-05-31 19:58:22','2026-05-31 19:58:32'),(22,'Dghj','诈骗欺诈',12,1,'completed',10,2,'2026-05-31 19:59:18','2026-05-31 19:59:26'),(23,'Dvnm','诈骗欺诈',12,1,'completed',8,4,'2026-05-31 20:02:34','2026-05-31 20:02:42'),(24,'Sghk','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 20:05:24','2026-05-31 20:05:33'),(25,'Sghk','诈骗欺诈',24,1,'completed',16,8,'2026-05-31 20:05:49','2026-05-31 20:06:03'),(26,'Chjkk','诈骗欺诈',12,1,'completed',9,3,'2026-05-31 20:31:33','2026-05-31 20:31:42'),(27,'gjnm','诈骗欺诈',24,1,'completed',17,7,'2026-05-31 20:48:36','2026-05-31 20:48:52'),(28,'hllon','诈骗欺诈',12,26,'completed',9,3,'2026-05-31 21:05:33','2026-05-31 21:05:43'),(29,'45666','诈骗欺诈',12,1,'completed',10,2,'2026-05-31 22:02:58','2026-05-31 22:03:07');
/*!40000 ALTER TABLE `tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('admin','user') DEFAULT 'user',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `idx_users_username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'admin','$2a$10$ST3q4Samm968Rg4y9qWsputESbGUMC9Cehhyo4w7aDfvq6Ajb13ya','admin','2026-05-26 12:00:55');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'airuan'
--

--
-- Dumping routines for database 'airuan'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-01  6:09:36
