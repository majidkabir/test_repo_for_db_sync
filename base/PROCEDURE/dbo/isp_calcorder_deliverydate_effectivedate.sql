SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*****************************************************************************************************/              
/* Stored Procedure: [isp_CalcOrder_DeliveryDate_EffectiveDate]                                      */              
/* Creation Date:                                                                                    */              
/* Copyright: IDS                                                                                    */              
/* Written by: kelvinongcy                                                                           */              
/*                                                                                                   */              
/* Purpose: https://jira.lfapps.net/browse/WMS-10707                                                 */              
/*                                                                                                   */              
/* Called By:                                                                                        */              
/*                                                                                                   */              
/* PVCS Version: 1.0                                                                                 */              
/*                                                                                                   */              
/* Version: 5.4                                                                                      */              
/*                                                                                                   */              
/* Data Modifications:                                                                               */              
/*                                                                                                   */              
/* Updates:                                                                                          */              
/* Date         Author    Ver.  Purposes                                                             */              
/* 14-10-19     kocy      1.0   Calculate the ORDERS.DeliveryDate AS RDD (Requested Delivery Date)   */    
/*                              AND ORDERS.EffectiveDate AS RAD (Requested Availability Date)        */   
/* 08/11/19     kocy01    1.1   Bug fix for not link sc.Facilty with o.Facility,  ssod.HolidayKey    */  
/*                              with HolidayHeader.HolidayKey                                        */  
/*****************************************************************************************************/    
CREATE PROCEDURE [dbo].[isp_CalcOrder_DeliveryDate_EffectiveDate]    
(   
   @c_StorerKey nvarchar(15), @c_ConfigKey nvarchar(30), @b_debug  bit = 0    
)    
AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS ON            
   SET ANSI_WARNINGS ON            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE   @c_SValue          INT    
            ,@c_ConsigneeKey    NVARCHAR(15)    
            ,@dt_DeliveryDate   DATETIME    
            ,@dt_AddDate   DATETIME    
            ,@dt_EffectiveDate   DATETIME    
            ,@dt_newDeliveryDate DATETIME    
            ,@n_cutOffHour      INT    
            ,@n_cutOffMin       INT    
            ,@n_continue        INT    
            ,@Err               INT    
            ,@c_errmsg          NVARCHAR(255)    
            ,@n_CutOffDay            INT    
            ,@c_AddrOvrFlag     NVARCHAR(5)    
            ,@c_OrderKey        NVARCHAR(15)    
            ,@c_HolidayKey      NVARCHAR(15)  
    
    
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT o.ConsigneeKey      
           , o.AddDate  
           , FORMAT(o.AddDate + ISNULL(ssod.DeliveryTerm,2), 'yyyy-MM-dd') + ' 00:00:00.000'  AS 'DeliveryDate'  -- DeliveryDate = o.AddDate + ssod.DeliveryTerm   
           , ISNULL(TRY_CAST(ssod.CutOffHour AS INT),0)    AS 'CutOffHour'    
           , ISNULL(TRY_CAST(ssod.CutOffMin AS INT),0)     As 'CutOffMin'  
           , ssod.HolidayKey  
           , ISNULL(ssod.AddrOvrFlag, '') AS 'Flag'              
           , CASE WHEN ISNULL(ssod.Sat, '0') = '1' THEN 5 ELSE      -- if ssod.Sat is turn on = 1, then set to 5    
             CASE WHEN ISNULL(ssod.Fri, '0') = '1' THEN 4 ELSE      -- if ssod.Fri is turn on = 1, then set to 4    
             CASE WHEN ISNULL(ssod.Thu, '0') = '1' THEN 3 ELSE      -- if ssod.Thu is turn on = 1, then set to 3    
             CASE WHEN ISNULL(ssod.Wed, '0') = '1' THEN 2 ELSE      -- if ssod.Wed is turn on = 1, then set to 2    
             CASE WHEN ISNULL(ssod.Tue, '0') = '1' THEN 1 ELSE      -- if ssod.Tue is turn on = 1, then set to 1    
             CASE WHEN ISNULL(ssod.Mon, '0') = '1' THEN 0 ELSE      -- if ssod.Mon is turn on = 1, then set to 0    
             CASE WHEN ISNULL(ssod.Sun, '0') = '1' THEN 6 ELSE '0' END END END END END END END  AS 'CutOffDay'  -- chosen latest day if multiple checked cut off days selection    
      FROM ORDERS AS o WITH (NOLOCK)    
      JOIN StorerConfig AS sc WITH (NOLOCK) ON sc.StorerKey = o.StorerKey  
      AND (sc.Facility = '' OR sc.Facility = o.Facility)           --kocy01  
      JOIN StorerSODefault AS ssod WITH (NOLOCK) ON ssod.StorerKey = o.ConsigneeKey
      AND sc.StorerKey = @c_StorerKey
      AND sc.ConfigKey = @c_ConfigKey -- 'CalcDeliveryOrder'  
      AND sc.SValue = '1'    
      AND o.[Status]  = '0'    
      AND o.EffectiveDate < = o.AddDate    
      AND (ssod.DeliveryTerm IS NOT NULL AND ssod.DeliveryTerm <> 0)    
        
      SELECT @Err = @@ERROR        
      IF @Err <> 0        
      BEGIN        
         SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'        
      END        
           
      OPEN CUR_ORD        
      FETCH NEXT FROM CUR_ORD INTO @c_ConsigneeKey, @dt_AddDate, @dt_DeliveryDate , @n_CutOffHour, @n_CutOffMin, @c_HolidayKey, @c_AddrOvrFlag, @n_CutOffDay    
           
      WHILE (@@FETCH_STATUS <> -1)    
      BEGIN    
             
         IF (@b_debug =1)    
         BEGIN    
           SELECT @c_OrderKey 'OrderKey', @c_ConsigneeKey 'ConsigneeKey', @c_StorerKey 'StorerKey', @dt_AddDate 'AddDate', @dt_DeliveryDate 'AddDate+DeliveryTerm'     
                , @n_CutOffHour 'CutOffHour', @n_CutOffMin 'CutOffMin', @c_AddrOvrFlag 'Flag', @n_CutOffDay 'CutOffDay'    
         END     
             
         SET @dt_newDeliveryDate = DATEADD(WEEK, DATEDIFF(WEEK,0,@dt_DeliveryDate),@n_CutOffDay)      
          
         IF @dt_newDeliveryDate < @dt_DeliveryDate    
         BEGIN    
            SET @dt_newDeliveryDate += 7    
         END    
    
         IF (@b_debug = 1)    
         BEGIN    
            SELECT @dt_newDeliveryDate  'New DeliveryDate After Compare CutOffDays'    
         END    
         -- If falls on holidays,  DeliveryDate increment by 1 days until it is not holidays       
         WHILE EXISTS ( SELECT 1 FROM  HolidayHeader AS h (NOLOCK)   
                        JOIN HolidayDetail AS hd (NOLOCK) ON h.HolidayKey  = hd.HolidayKey   
                        WHERE h.HolidayKey = ISNULL(@c_HolidayKey, '')  
                        AND hd.HolidayDate =  @dt_newDeliveryDate )  --kocy01  
         BEGIN    
            SET @dt_newDeliveryDate += 1    
         END    
    
         IF (@b_debug = 1)    
         BEGIN    
            SELECT @dt_newDeliveryDate  'New DeliveryDate If Falls on holidays'    
         END    
    
         SET @dt_EffectiveDate = DATEADD(MINUTE, @n_cutOffMin, DATEADD(HOUR, @n_cutOffHour, @dt_newDeliveryDate))    
    
         -- If falls on holidays,  EffectiveDate increment by 1 days until it is not holidays    
         WHILE EXISTS ( SELECT 1 FROM  HolidayHeader AS h (NOLOCK)   
                        JOIN HolidayDetail AS hd (NOLOCK) ON h.HolidayKey  = hd.HolidayKey   
                        WHERE h.HolidayKey = ISNULL(@c_HolidayKey, '')  
                       AND hd.HolidayDate =  @dt_EffectiveDate )    --kocy01  
         BEGIN    
            SET @dt_EffectiveDate += 1    
         END    
    
         IF (@b_debug = 1)    
         BEGIN    
            SELECT @dt_EffectiveDate  'New EffectiveDate If Falls on holidays'    
         END    
    
         -- compare month of new DeliveryDate with existing AddDate if different  and the ssod.AddOvrFlag =  'Y', then skip to perform update ;    
         IF (DATEPART (MONTH, @dt_AddDate) < DATEPART (MONTH, @dt_newDeliveryDate)) AND @c_AddrOvrFlag = 'Y'    
         BEGIN    
            GOTO NEXT_ORD    
         END    
             
           DECLARE CUR_UPD_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
           SELECT o.OrderKey     
           FROM ORDERS AS o WITH (NOLOCK)    
           WHERE o.StorerKey = @c_StorerKey AND    
           o.ConsigneeKey = @c_ConsigneeKey    
               
           OPEN CUR_UPD_ORD    
           FETCH NEXT FROM CUR_UPD_ORD INTO @c_OrderKey    
           WHILE (@@FETCH_STATUS <> -1)    
           BEGIN    
             UPDATE ORDERS WITH (ROWLOCK)     
             SET DeliveryDate = @dt_newDeliveryDate,    
                 EffectiveDate = @dt_EffectiveDate     
              WHERE OrderKey = @c_OrderKey    
              AND AddDate = @dt_AddDate    
                                 
              FETCH NEXT FROM CUR_UPD_ORD INTO @c_OrderKey    
           END             
           CLOSE CUR_UPD_ORD                    
           DEALLOCATE CUR_UPD_ORD    
    
    
        NEXT_ORD:    
        FETCH NEXT FROM CUR_ORD INTO @c_ConsigneeKey, @dt_AddDate, @dt_DeliveryDate, @n_CutOffHour, @n_CutOffMin,@c_HolidayKey, @c_AddrOvrFlag, @n_CutOffDay    
     END    
     CLOSE CUR_ORD            
     DEALLOCATE CUR_ORD      
    
END -- End SP

GO