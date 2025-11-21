SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nsp_BackEndShip_Job                                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Update PickDetail to Status 9 from backend                  */  
/*                                                                      */  
/* Return Status: None                                                  */  
/*                                                                      */  
/* Usage: For Backend Schedule job                                      */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: SQL Schedule Job                                          */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 2010-Sep-05  Shong         Add Parameter for StorerKey               */  
/* 2011-Jan-10  TLTING        Enhance on Storer Filter (TLTING01)       */  
/* 2011-Oct-20  TLTING        Performance tune                          */  
/* 2013-Feb-20  SWYep         EditDate Update                           */  
/* 2011-Oct-20  TLTING02      Performance tune                          */  
/* 2013-Apr-23  Leong         Include debug mode (Leong01)              */  
/* 2013-Jul-08  TLTING03      Auto insert Storerkey in Codelkup         */  
/* 2017-Feb-22  TLTING04      Performance tune                          */  
/* 2018-Aug-01  SWT01         Performance Tuning                        */   
/* 2019-Jun-13  TLTING05      performance tune- optimised               */ 
/* 2019-Jun-13  TLTING06      performance tune                          */ 
/************************************************************************/  
CREATE    PROCEDURE [dbo].[nsp_BackEndShip_Job]  
     @c_StorerKey NVARCHAR(10) = '%'  
   , @b_debug     INT = 0 -- Leong01  
AS  
BEGIN -- main  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_EffectiveDate DATETIME,  
           @c_Mbolkey       NVARCHAR(10),  
           @c_ShipCounter   NVARCHAR(10),  
           @f_status        INT  
  
   -- tlting01  
   IF ISNULL(RTRIM(@c_StorerKey),'') <> '%'  
   BEGIN  
      -- The Storerkey parameter value must insert into Codelkup - 'SHIPSTORER'  
      IF NOT EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK) WHERE C.LISTNAME  = 'SHIPSTORER' AND C.Code = @c_StorerKey )  
      BEGIN  
            -- MAke sure backendship run from SQL Job, then auto insert codelkup  
         IF EXISTS ( select 1 from master.dbo.sysprocesses where [program_name] like 'SQLAgent - TSQL%' and spid = @@spid )  
         BEGIN  
            INSERT INTO Codelkup (Listname, Code, Description )  
            values ('SHIPSTORER',@c_StorerKey,'BackEndShip by Storer')              
         END           
      END        
      -- SWT01  
      DECLARE C_MBOLFIND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         -- TLTING06  
         --SELECT  TOP 100 MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter      
         --FROM MBOL (NOLOCK)       
         --JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)      
         --JOIN  ( SELECT    ORDERS.OrderKey      
         --         FROM ORDERS WITH (NOLOCK )   
         --         WHERE ORDERS.StorerKey = @c_StorerKey      
         --         AND EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)      
         --                        WHERE C.LISTNAME  = N'SHIPSTORER'      
         --                        AND C.Code = ORDERS.StorerKey )      
         --         AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK )      
         --                        WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey       
         --                        AND PICKDETAIL.Status < '9' )      
         --         GROUP BY ORDERS.OrderKey  )  AS  A   ON A.OrderKey  = MBOLDETAIL.OrderKey      
         --WHERE MBOL.Status = '9'      
         --GROUP BY MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter   
         --ORDER BY MBOL.ShipCounter,  MBOL.EffectiveDate  , MBOL.MBOLKey DESC     
  
  
         SELECT  TOP 100 MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter    
         FROM MBOL (NOLOCK)     
         JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
         JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey    
         WHERE MBOL.Status = '9'    
         AND ORDERS.StorerKey = @c_StorerKey    
         AND EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)    
                        WHERE C.LISTNAME  = 'SHIPSTORER'    
                        AND C.Code = ORDERS.StorerKey )    
         AND EXISTS ( SELECT 1 FROM PICKDETAIL (NOLOCK)    
                        WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey     
                        AND PICKDETAIL.Status < '9' )
         GROUP BY MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter                         
         ORDER BY MBOL.ShipCounter,  MBOL.EffectiveDate  , MBOL.MBOLKey DESC   
         OPTION (MAXDOP 1, USE HINT('DISABLE_OPTIMIZER_ROWGOAL' )  )
         -- OPTION ( MAXDOP 1, QUERYTRACEON 4138) -- disable the row goal
         --OPTION (OPTIMIZE FOR UNKNOWN)  --TLTING05  
  

         --SELECT DISTINCT  MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter  
         --FROM ORDERDETAIL WITH (NOLOCK)  
         --JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = ORDERDETAIL.MBOLKey AND MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey  
         --JOIN MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)  
         --WHERE MBOL.Status = '9'  
         --AND ORDERDETAIL.StorerKey = @c_StorerKey  
         --AND EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)  
         --               WHERE C.LISTNAME  = 'SHIPSTORER'  
         --               AND C.Code = ORDERDETAIL.StorerKey )  
         --AND EXISTS ( SELECT 1 FROM PICKDETAIL (NOLOCK)  
         --               WHERE PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
         --               PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER  
         --               AND PICKDETAIL.Status < '9' )  
         --ORDER BY MBOL.ShipCounter,  MBOL.EffectiveDate  , MBOL.MBOLKey DESC  
  
                    
   END  
   ELSE  
   BEGIN  
    -- SWT01  
      DECLARE C_MBOLFIND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         -- TLTING06
         SELECT  TOP 100  MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter    
         FROM MBOL (NOLOCK)     
         JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
         JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey    
         WHERE MBOL.Status = '9'    
         AND NOT EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)    
                        WHERE C.LISTNAME  = 'SHIPSTORER'    
                        AND C.Code = ORDERS.StorerKey )    
         AND EXISTS ( SELECT 1 FROM PICKDETAIL (NOLOCK)    
                        WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey     
                        AND PICKDETAIL.Status < '9' ) 
         GROUP BY MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter                         
         ORDER BY MBOL.ShipCounter,  MBOL.EffectiveDate  , MBOL.MBOLKey DESC    
         OPTION (MAXDOP 1, USE HINT('DISABLE_OPTIMIZER_ROWGOAL' )  )
         -- OPTION ( MAXDOP 1, QUERYTRACEON 4138)  -- disable the row goal
         
         
         -- tlting04  
         --SELECT MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter  
         --FROM MBOL (NOLOCK)  
         --JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)  
         --JOIN ( SELECT ORDERDETAIL.OrderKey,  ORDERDETAIL.MbolKey   
         --         FROM ORDERDETAIL  (NOLOCK)   
         --         JOIN PICKDETAIL with (NOLOCK) ON  PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey  
         --                        AND PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER   
         --         WHERE PICKDETAIL.Status < '9'  
         --         AND NOT EXISTS ( SELECT 1 from Codelkup C (NOLOCK)  
         --            WHERE C.LISTNAME  = 'SHIPSTORER'  
         --            AND C.Code = ORDERDETAIL.StorerKey )  
         --         GROUP BY ORDERDETAIL.StorerKey, ORDERDETAIL.OrderKey,  ORDERDETAIL.MbolKey  )  
         --            AS A ON A.OrderKey = MBOLDETAIL.OrderKey AND A.MBOLKey = MBOLDETAIL.MBOLKey  
         --WHERE MBOL.Status = '9'  
         --GROUP BY MBOL.MBOLKey, MBOL.EffectiveDate, MBOL.ShipCounter  
         --ORDER BY MBOL.ShipCounter, MBOL.EffectiveDate, MBOL.MBOLKey DESC  
   END  
  
   OPEN C_MBOLFIND  
   FETCH NEXT FROM C_MBOLFIND INTO @c_Mbolkey, @c_EffectiveDate, @c_ShipCounter  
  
   SELECT @f_status = @@FETCH_STATUS  
  
   WHILE @f_status <> -1  
   BEGIN  
      BEGIN  
         BEGIN TRAN  
            -- Update EffectiveDate so if BackEndShip fails then this one is put to back of queue.  
            UPDATE MBOL WITH (ROWLOCK)  
            SET MBOL.EffectiveDate = GETDATE()  
              , EditDate = GETDATE()           --(SW01)  
              , TrafficCop = NULL  
            WHERE MBOLKey = @c_Mbolkey  
         COMMIT TRAN  
           
         BEGIN TRAN  
            -- Update Userdefine10 to show which attempt this was on executing.  
            UPDATE MBOL WITH (ROWLOCK)  
            SET MBOL.ShipCounter = isnull(LTrim(ShipCounter),0)+1  
              , EditDate = GETDATE()           --(SW01)  
              , TrafficCop = NULL  
            WHERE MBOLKey = @c_Mbolkey  
         COMMIT TRAN  
      END  
  
      EXEC nsp_BackEndShipped4 @c_StorerKey, @c_Mbolkey, @b_debug -- Leong01  
        
      FETCH NEXT FROM C_MBOLFIND INTO @c_Mbolkey, @c_EffectiveDate,@c_ShipCounter  
  
      SELECT @f_status = @@FETCH_STATUS  
   END  
  
   CLOSE C_MBOLFIND  
   DEALLOCATE C_MBOLFIND  
END  

GO