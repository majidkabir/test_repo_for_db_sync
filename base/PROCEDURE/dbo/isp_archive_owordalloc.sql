SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Archive_OWORDAlloc               */  
/* Creation Date: 09-Jan-2004                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YokeBeen                                                 */  
/*                                                                      */  
/* Purpose: HouseKeeping DX Temp Table (OWORDALLOC) (SOS#18664)         */  
/*                                                                      */  
/* Called By: SQL Schedule Job                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Purposes                                       */  
/* 06.Nov.06    June     SOS61501 - Remove Join to Orders table  			*/  
/*                       when purge exe2ow_allocpickship records. 		*/  
/* 22.Sep.08    TLTING	 Purge exe2ow_allocpickship when 			      */
/*							    transmitflag = "9" when order exists           */ 
/*                       If orders not exists, then delete  (tlting01) */   
/* 30.Jan.18    TLTING	 Status '5'                                     */
/************************************************************************/  
   
   
CREATE PROC [dbo].[isp_Archive_OWORDAlloc] (  
   @c_TargetDBName NVARCHAR(20),  
   @n_daysretain     Int  
)  
AS  
-- Created by YokeBeen on 09-Jan-2004 for HouseKeeping DX Temp Table (OWORDALLOC)   
-- (SOS#18664)  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
        
 DECLARE @n_continue    int  
   , @b_success   int  
   , @n_err     int  
   , @c_errmsg    NVARCHAR(20)  
     , @n_starttcnt   int  -- Holds the current transaction count    
   , @b_debug    int  
  
 DECLARE @cExecStatements nvarchar(1000)   
 SELECT @cExecStatements = ''  
  
   SELECT @b_debug = 0  
 SELECT @n_continue = 1  
  
  
/* 1.0 Process on Archiving Table - Start  */  
/*******************************************/  
 IF (@n_continue = 1) OR (@n_continue = 2)  
 BEGIN  
  -- Transfer To Archive Table  
  BEGIN TRAN  
   SELECT @cExecStatements = N'INSERT INTO ' + dbo.fnc_RTrim(@c_TargetDBName) + '..OWORDALLOC '  
            + 'SELECT * '  
            + 'FROM OWORDALLOC (NOLOCK) '  
            + 'WHERE DATEDIFF(DAY, TLDATE, GETDATE()) > ' + CAST(@n_daysretain AS CHAR) + ' '   
            + 'AND TransmitFlag in ( "5", "9")'  
  
   EXEC sp_executesql @cExecStatements   
  
       IF @@ERROR = 0  
   BEGIN   
        IF @b_debug = 1  
        BEGIN  
           SELECT 'Archiving OWORDALLOC - Insertion Done !'  
        END  
   
          COMMIT TRAN  
       END  
       ELSE  
       BEGIN  
          ROLLBACK TRAN  
          SELECT @n_continue = 3  
    SELECT @n_err = 63810  
          SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Insert records failed (isp_Archive_OWORDAlloc)'    
   END   
  
  
  -- Purge Inserted Records  
  BEGIN TRAN  
   SELECT @cExecStatements = N'DELETE OWORDALLOC '  
            + 'FROM OWORDALLOC '  
            + 'JOIN ' + dbo.fnc_RTrim(@c_TargetDBName) + '..OWORDALLOC A (NOLOCK) '  
            + 'ON (OWORDALLOC.TransmitLogKey = A.TransmitLogKey) '  
            + 'WHERE OWORDALLOC.TransmitFlag in ( "5", "9") '  
  
   EXEC sp_executesql @cExecStatements   
  
       IF @@ERROR = 0  
   BEGIN   
        IF @b_debug = 1  
        BEGIN  
           SELECT 'Archiving OWORDALLOC - OWORDALLOC Purging Done !'  
        END  
   
          COMMIT TRAN  
       END  
       ELSE  
       BEGIN  
          ROLLBACK TRAN  
          SELECT @n_continue = 3  
    SELECT @n_err = 63811  
          SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Delete records failed (isp_Archive_OWORDAlloc)'    
   END   
  
  
  -- Purge EXE2OW_AllocPickShip Table  - Part 1
  BEGIN TRAN   
   -- Start : SOS61501  
      -- tlting01 
   SELECT @cExecStatements = N'DELETE EXE2OW_AllocPickShip '   
            + 'FROM  ORDERS (NOLOCK) '  
            + 'JOIN  TRANSMITLOG (NOLOCK) ON (ORDERS.ORDERKEY = TRANSMITLOG.KEY1) '  
            + 'WHERE  TRANSMITLOG.TABLENAME = "OWORDSHIP" '  
            + 'AND    TRANSMITLOG.TRANSMITFLAG = "9"'  
            + 'AND    EXE2OW_AllocPickShip.ExternOrderKey = ORDERS.ExternOrderKey '  
            + 'AND    DATEDIFF(DAY, EXE2OW_AllocPickShip.Adddate, GETDATE()) > ' + CAST(@n_DaysRetain AS CHAR) + ' '   
              
/*   SELECT @cExecStatements = N'DELETE EXE2OW_AllocPickShip '   
            + 'WHERE DATEDIFF(DAY, EXE2OW_AllocPickShip.Adddate, GETDATE()) > ' + CAST(@n_DaysRetain AS CHAR) + ' '   
*/            
   -- End : SOS61501  
   
   EXEC sp_executesql @cExecStatements   
  
   IF @@ERROR = 0  
   BEGIN   
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Archiving OWORDALLOC - EXE2OW_AllocPickShip Part 1 Purging Done !'  
      END  
   
      COMMIT TRAN  
   END  
   ELSE  
   BEGIN  
      ROLLBACK TRAN  
      SELECT @n_continue = 3  
      SELECT @n_err = 63812  
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Delete records failed (isp_Archive_OWORDAlloc)'    
   END   
   
  -- Purge EXE2OW_AllocPickShip Table  - Part 2
  BEGIN TRAN      
   -- tlting01 Start
   SELECT @cExecStatements = N'DELETE EXE2OW_AllocPickShip '   
   			+ ' FROM EXE2OW_AllocPickShip (NOLOCK) '
   			+ ' 		LEFT JOIN  ORDERS (NOLOCK) ON ( EXE2OW_AllocPickShip.ExternOrderKey = ORDERS.ExternOrderKey ) '
			+ ' WHERE   ORDERS.ExternOrderKey IS NULL '
            + ' AND    DATEDIFF(DAY, EXE2OW_AllocPickShip.Adddate, GETDATE()) > ' + CAST(@n_DaysRetain AS CHAR) + ' '   
   -- tlting01 END         
   EXEC sp_executesql @cExecStatements   
  
   IF @@ERROR = 0  
   BEGIN   
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Archiving OWORDALLOC - EXE2OW_AllocPickShip Part 2 Purging Done !'  
      END  
   
      COMMIT TRAN  
   END  
   ELSE  
   BEGIN  
      ROLLBACK TRAN  
      SELECT @n_continue = 3  
      SELECT @n_err = 63813  
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Delete records failed (isp_Archive_OWORDAlloc)'    
   END   
      
 END -- IF (@n_continue = 1)  
/********************************************/  
/*  1.0 Process on Archiving Table - End  */  
  
  
   /* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
   BEGIN    
          COMMIT TRAN    
         END    
      END    
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Archive_OWORDAlloc'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
 END    
END  

GO