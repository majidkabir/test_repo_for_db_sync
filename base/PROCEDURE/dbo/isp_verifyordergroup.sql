SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_VerifyOrderGroup                               */    
/* Creation Date: 22-Jun-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: LIM KAH HWEE                                             */    
/*                                                                      */    
/* Purpose: Back End job to check for Shipment/Cancellation Confirm     */  
/*          interfaces                                                  */    
/*                                                                      */    
/*                                                                      */    
/* Called By: BEJ - Verify Order Group                                  */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author Ver Purposes                                     */    
/* 2010-09-18   ChewKP 1.1 Should filter by storerkey (ChewKP01)        */   
/* 2010-11-08   MCTang 1.1 Verify Status (MC01)                         */ 
/* 2010-12-23   MCTang 1.2 Remove IML_LOG (MC02)                        */ 
/************************************************************************/    
CREATE PROC [dbo].[isp_VerifyOrderGroup]          
(    
   @cStorerKey  NVARCHAR(15)    
,  @b_Debug     INT = 0  
)    
AS    
BEGIN    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
    
DECLARE @cOrdGrp     NVARCHAR(20),    
        @nCnt        INTEGER,  
        @nTcnt       INTEGER,    
        @c_Key1      NVARCHAR(10),  
        @c_SoStatus  NVARCHAR(10)  
    
DECLARE curODR CURSOR LOCAL FAST_FORWARD READ_ONLY    
FOR    
   SELECT DISTINCT OrderGroup    
   FROM   ORDERS WITH (NOLOCK)    
   WHERE  OrderGroup <> ''    
   AND StorerKey = @cStorerKey    
   AND EXISTS (SELECT 1 FROM TRANSMITLOG3 WITH (NOLOCK)    
               WHERE tablename IN ('SOCFMLOG', 'CANCSOLOG')     
               AND TRANSMITLOG3.key1 = ORDERS.OrderKey     
               AND TRANSMITLOG3.key3 = ORDERS.StorerKey    
               AND TransmitBatch = ''  
               AND ORDERS.Storerkey  = @cStorerkey )   -- (ChewKP01)  
    
OPEN curODR    
FETCH NEXT FROM curODR INTO @cOrdGrp    
    
WHILE @@FETCH_STATUS <> -1    
BEGIN    
   SET @nCnt = 0   
  
   SELECT @nCnt = COUNT(1)  
   FROM   ORDERS WITH (NOLOCK)   
   WHERE  OrderGroup = @cOrdGrp  
   AND    StorerKey = @cStorerKey   
  
   SET @nTcnt = 0    
    
   SELECT @nTcnt = COUNT(1)   
   FROM TRANSMITLOG3    
   WHERE tablename IN ('SOCFMLOG', 'CANCSOLOG')    
   AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
               WHERE OrderKey = TRANSMITLOG3.key1     
               AND StorerKey = TRANSMITLOG3.key3     
               AND OrderGroup = @cOrdGrp  
               AND Storerkey = @cStorerkey)    -- (ChewKP01)  
  
   IF @b_debug = 1  
   BEGIN  
      select @nCnt '@nCnt', @cOrdGrp '@cOrdGrp', @nTcnt '@nTcnt'  
   END  
    
   IF @nTcnt = @nCnt    
   BEGIN    
      UPDATE TRANSMITLOG3 WITH (ROWLOCK)    
        SET TransmitBatch = '1'     
      WHERE TransmitBatch = ''    
      AND tablename IN ('SOCFMLOG', 'CANCSOLOG')    
      AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
               WHERE ORDERS.OrderKey = TRANSMITLOG3.key1     
               AND ORDERS.StorerKey = TRANSMITLOG3.key3     
               AND ORDERS.OrderGroup = @cOrdGrp  
               AND ORDERS.Storerkey = @cStorerkey)    -- (ChewKP01)  
   -- MC02 - S
   /*
   Insert IML_LOG (nCnt, OrdGrp, nTCnt)    -- BY MCTang Testing  
   Values (@nCnt,@cOrdGrp,@nTcnt )  
   */
   -- MC02 - E   
   END    
   -- MC01 - S  
   ELSE IF @nTcnt > @nCnt   
   BEGIN  
      SET @c_Key1 = ''  
  
      DECLARE curDouble CURSOR LOCAL FAST_FORWARD READ_ONLY    
      FOR SELECT key1 from TRANSMITLOG3    
          WHERE tablename IN ('SOCFMLOG', 'CANCSOLOG')    
          AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
                     WHERE OrderKey = TRANSMITLOG3.key1     
                     AND StorerKey = TRANSMITLOG3.key3     
                     AND OrderGroup = @cOrdGrp  
                     AND Storerkey = @cStorerkey)     
          GROUP BY Key1  
          HAVING COUNT(1) > 1  
  
      OPEN curDouble    
      FETCH NEXT FROM curDouble INTO @c_Key1    
          
      WHILE @@FETCH_STATUS <> -1    
      BEGIN   
  
         SET @c_SoStatus = ''  
  
         SELECT @c_SoStatus = ISNULL(SOSTATUS, '')   
         FROM ORDERS (NOLOCK)   
         WHERE ORDERKEY = @c_Key1  
  
         IF @c_SoStatus = 'CANC'   
         BEGIN  
            DELETE FROM TRANSMITLOG3   
            WHERE tablename = 'SOCFMLOG'   
            AND key1 = @c_Key1  
            AND key3 = @cStorerkey   
            AND transmitflag = '0'  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'OrderKey : ' + @c_Key1 + ', Group : ' + @cOrdGrp  
               SELECT 'Delete SOCFMLOG '  
            END  
         END  
         ELSE  
         BEGIN  
            DELETE FROM TRANSMITLOG3   
            WHERE tablename = 'CANCSOLOG'   
            AND key1 = @c_Key1  
            AND key3 = @cStorerkey   
            AND transmitflag = '0'  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'OrderKey : ' + @c_Key1 + ', Group : ' + @cOrdGrp  
               SELECT 'Delete CANCSOLOG '  
            END  
         END  
  
         FETCH NEXT FROM curDouble INTO @c_Key1     
      END   
  
      CLOSE curDouble    
      DEALLOCATE curDouble    
  
   END  
   -- MC01 - E  
    
   FETCH NEXT FROM curODR INTO @cOrdGrp     
END    
    
CLOSE curODR    
DEALLOCATE curODR    
    
END /* main procedure */  

GO