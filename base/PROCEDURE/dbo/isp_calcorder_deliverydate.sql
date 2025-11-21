SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************************************/                
/* Stored Procedure: [isp_CalcOrder_DeliveryDate]                                                    */                
/* Creation Date:                                                                                    */                
/* Copyright: IDS                                                                                    */                
/* Written by: kelvinongcy                                                                           */                
/*                                                                                                   */                
/* Purpose: https://jira.lfapps.net/browse/WMS-16732                                                 */                
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
/* 09-04-21     kocy      1.0   Calculate the ORDERS.DeliveryDate AS RDD (Requested Delivery Date)   */      
/*                                                                                                   */     
/*****************************************************************************************************/   
CREATE PROCEDURE [dbo].[isp_CalcOrder_DeliveryDate]  
(  
   @c_StorerKey nvarchar(15), @c_ConfigKey nvarchar(30), @n_debug int = 0  
)  
AS  
   SET NOCOUNT ON;  
   SET ANSI_NULLS OFF;  
   SET ANSI_WARNINGS OFF;  
   SET QUOTED_IDENTIFIER OFF;  
   SET CONCAT_NULL_YIELDS_NULL OFF;  
BEGIN  
   DECLARE    
            @c_OrderKey NVARCHAR (10)  
           ,@d_AddDate  DATETIME  
           ,@c_HolidayKey NVARCHAR(10)  
           ,@c_DocType NVARCHAR(2)   
           ,@c_CutOffTime NVARCHAR(10)  
           ,@n_NoOfdays INT  
           ,@n_DayException NVARCHAR(25)  
           ,@d_DeliveryDate DATETIME  
           ,@c_Weekdays NVARCHAR(10)  
           ,@b_success  INT   
           ,@n_err      INT  
           ,@c_errmsg   NVARCHAR (255)  
           ,@n_continue INT  
           ,@n_starttcnt INT  
             
   /********** Initial parameter values **************/   
   SELECT  @n_continue = 1, @b_success = 0, @n_err  = '', @n_starttcnt = @@TRANCOUNT  
    
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT o.OrderKey  
            ,o.AddDate  
            ,clk.Long          -- HolidayHeader.HolidayKey  
            ,clk.Short         -- Orders.DocType  
            ,clk.UDF01         -- CutOfftime  
            ,clk.UDF02         -- Buffer in Day  
            ,clk.Notes         -- Weekend                
      FROM dbo.Orders o WITH (NOLOCK)  
      JOIN dbo.StorerConfig sc  WITH (NOLOCK) ON sc.StorerKey = o.StorerKey AND (sc.Facility = '' OR sc.Facility = o.Facility)  
      JOIN Codelkup clk ON (clk.Listname = @c_ConfigKey AND clk.StorerKey = @c_StorerKey AND o.DocType = clk.Short)  
      WHERE sc.ConfigKey = @c_ConfigKey  
      AND sc.StorerKey = @c_StorerKey  
      AND sc.SValue = '1'  
      AND o.[Status] = '0'  
      AND o.UpdateSource = 0   
      --AND o.OrderKey  IN ('0006774420', '0006774419')  
        
      SELECT @n_err = @@ERROR          
      IF @n_err <> 0          
      BEGIN  
         SET @n_continue = 3
         SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'  
         
      END    
  
      OPEN CUR_ORD  
      FETCH NEXT FROM CUR_ORD INTO @c_OrderKey, @d_AddDate, @c_HolidayKey, @c_DocType, @c_CutOffTime, @n_NoOfdays, @n_DayException  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         IF (@n_debug = 1)      
         BEGIN      
            SELECT @d_AddDate  'AddDate'      
         END  
  
         IF  CAST (@d_AddDate AS time) > @c_CutOffTime  
         BEGIN  
            SET @n_NoOfdays = @n_NoOfdays + 1  
  
            SELECT @d_DeliveryDate = convert(varchar(10),@d_AddDate, 120)  
            SET @d_DeliveryDate +=@n_NoOfDays  
  
            WHILE EXISTS ( SELECT 1 FROM HolidayHeader AS h (NOLOCK)   
                            JOIN HolidayDetail AS hd (NOLOCK) ON h.HolidayKey = hd.HolidayKey  
                            JOIN Codelkup AS clk (NOLOCK) ON clk.Listname = @c_ConfigKey AND clk.StorerKey = @c_StorerKey AND clk.Long = h.HolidayKey  
                            WHERE h.HolidayKey = ISNULL (@c_HolidayKey, '')  
                            AND hd.HolidayDate = @d_DeliveryDate  ) OR DATENAME (weekday, @d_DeliveryDate) IN ('Saturday', 'Sunday')  
            BEGIN            
                  SET @d_DeliveryDate +=@n_NoOfDays   
            END     
         END  
         ELSE  
         BEGIN  
            SET @n_NoOfdays = @n_NoOfdays  
  
            SELECT @d_DeliveryDate = convert(varchar(10),@d_AddDate, 120)  
            SET @d_DeliveryDate +=@n_NoOfDays  
  
            WHILE EXISTS ( SELECT 1 FROM HolidayHeader AS h (NOLOCK)   
                            JOIN HolidayDetail AS hd (NOLOCK) ON h.HolidayKey = hd.HolidayKey  
                            JOIN Codelkup AS clk (NOLOCK) ON clk.Listname = @c_ConfigKey AND clk.StorerKey = @c_StorerKey AND clk.Long = h.HolidayKey  
                            WHERE h.HolidayKey = ISNULL (@c_HolidayKey, '')  
                            AND hd.HolidayDate = @d_DeliveryDate  ) OR DATENAME (weekday, @d_DeliveryDate) IN ('Saturday', 'Sunday')  
            BEGIN            
                  SET @d_DeliveryDate +=@n_NoOfDays   
            END     
         END  
           
         IF (@n_debug = 1)      
         BEGIN      
            SELECT @d_DeliveryDate  'AddDate Falls on workday/weekend/holidays. next DeliveryDate will be'      
         END    
               
         BEGIN TRAN  

            UPDATE ORDERS WITH (ROWLOCK)  
            SET DeliveryDate = @d_DeliveryDate  
            , UpdateSource = 1  
            WHERE OrderKey = @c_OrderKey  

            IF @@ROWCOUNT = 0 OR @@ERROR <> 0                                     
            BEGIN                                      
               SET @n_continue = 3
               SET @n_err = @@ERROR
               SET @c_errmsg = N'Failed Updated Orders DeliveryDate via' + '('+OBJECT_NAME(@@PROCID)+').'
               ROLLBACK TRAN 
            END 

         WHILE @@TRANCOUNT > 0        
         COMMIT TRAN  
              
        FETCH NEXT FROM CUR_ORD INTO @c_OrderKey, @d_AddDate, @c_HolidayKey, @c_DocType, @c_CutOffTime, @n_NoOfdays, @n_DayException  
  
      END --(@@FETCH_STATUS <> -1)  
      CLOSE CUR_ORD  
      DEALLOCATE CUR_ORD  

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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_CalcOrder_DeliveryDate'         
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