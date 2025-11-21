SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
          
/*********************************************************************************************/            
/* Stored Procedure: [isp_TransmitSMS_Converse]                                              */            
/* Creation Date:                                                                            */            
/* Copyright: IDS                                                                            */            
/* Written by: kelvinongcy                                                                   */            
/*                                                                                           */            
/* Purpose: Sent SMS for shipped orders according respective StorerKey                       */              
/*                                                                                           */            
/* Called By:                                                                                */            
/*                                                                                           */            
/* PVCS Version: 1.0                                                                         */            
/*                                                                                           */            
/* Version: 5.4                                                                              */            
/*                                                                                           */            
/* Data Modifications:                                                                       */            
/*                                                                                           */            
/* Updates:                                                                                  */            
/* Date        Author         Ver.  Purposes                                                 */                          
/* 2019-09-23  kelvinongcy    1.0   WMS-10448 customized for Converse                        */            
/* 2022-09-26  kelvinongcy    1.1   WMS-20867 enhance to support CN ALC SMS platform         */             
/*                                  use json pass parameter                                  */            
/*                                  (remark: each param sustain 35 char only)                */     
/*2022-10-18   kelvinongcy    1.2   WMS-20867 remove check order status (kocy02)             */    
/*********************************************************************************************/                     
            
CREATE   PROCEDURE [dbo].[isp_TransmitSMS_Converse]                         
(             
  @StorerKey NVARCHAR(15),                         
  @Debug      INT = 0             
)                        
AS                           
BEGIN                        
   SET NOCOUNT ON                        
   SET ANSI_NULLS ON                        
   SET ANSI_WARNINGS ON                        
   SET QUOTED_IDENTIFIER OFF                        
   SET CONCAT_NULL_YIELDS_NULL OFF                          
                        
   DECLARE    @ConsigneeKey               NVARCHAR(15)                  
             ,@ExternOrderKey             NVARCHAR(15)                
             ,@SumOriginalQty             NVARCHAR(15)                 
             ,@TotalSumQriginalQty        NVARCHAR(15)                
             ,@GrandTotalSumQriginalQty   NVARCHAR(15)              
             ,@MobileNo                   NVARCHAR(15)                    
             ,@LoadPlanAddDate            NVARCHAR(15)                 
             ,@Err                        INT    = 0                 
             ,@ErrMsg                     NVARCHAR(255)                    
             ,@ErrSeverity                INT                 
             ,@dBegin                     DATETIME                    
             ,@RowCount                   INT            
             ,@c_AlertKey                 CHAR(18)                  
             ,@Qid                        INT                
             ,@cSubject                   NVARCHAR(15)                    
             ,@c_SMSBody                  NVARCHAR(MAX)            
             ,@c_SMSBody2                 NVARCHAR(MAX)            
             ,@cSQL                       NVARCHAR(MAX)                
             ,@TotalLoadKey               INT                
    ,@OrderKey                   NVARCHAR(15)                
             ,@mail_id                    INT  = 0              
      ,@concatenate                NVARCHAR (255)            
                
   DECLARE @mailQSMS table( Qid int NOT NULL)                
   DECLARE @DBMailQueue table (mail_id int NOT NULL)                
                
                 
   SELECT @Err = 0, @ErrMsg = '', @ErrSeverity = 0 ,  @c_SMSBody = '',  @TotalLoadKey = 0                
                
   DECLARE CUR_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT  o.ConsigneeKey,  FORMAT(l.AddDate, 'MM/dd'), A.C_Phone1                
   FROM  ORDERS o  WITH (NOLOCK)                  
   JOIN ORDERDETAIL od WITH (NOLOCK) ON o.OrderKey = od.OrderKey                
   JOIN STORER c WITH (NOLOCK) ON o.ConsigneeKey = c.StorerKey                       
   JOIN LoadPlanDetail lp WITH (NOLOCK) ON lp.OrderKey = o.OrderKey                
   JOIN LoadPlan l WITH (NOLOCK) ON l.LoadKey = o.LoadKey                
   CROSS APPLY                
   (  /* sent to 1st recipient's contact only if mutliple */                
      SELECT TOP 1 C_Phone1                
      FROM ORDERS  WITH (NOLOCK)                
      WHERE StorerKey = o.StorerKey                            
         AND [Status] = o.[Status]                
         AND ConsigneeKey =o.ConsigneeKey   
         AND C_Phone1 LIKE '+861%'                  
         AND LEN(C_Phone1) = 14    
   ) AS A                
   WHERE o.StorerKey = @StorerKey                     
   --AND o.[Status] = '9'         -- kocy02    
   AND o.Doctype = 'N'            
   AND o.[Type] <> 'Transfer'            
   AND l.AddDate BETWEEN CONVERT(VARCHAR(10), GETDATE() -1, 120)  AND CONVERT(VARCHAR(10), GETDATE(), 120)              
   AND NOT EXISTS ( SELECT 1 FROM MailQSMSDet (NOLOCK) WHERE MailQSMSDet.OrderKey = o.OrderKey)                
   GROUP BY o.ConsigneeKey , FORMAT(l.AddDate, 'MM/dd'), A.C_Phone1         
   ORDER BY FORMAT(l.AddDate, 'MM/dd')    
                   
   SELECT @Err = @@ERROR                
   IF @Err <> 0                
   BEGIN                
      SET @ErrMsg = 'NSQL'+CONVERT(Char(5),@Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'                
   END                
                 
   OPEN CUR_1                  
   FETCH NEXT FROM CUR_1 INTO @ConsigneeKey, @LoadPlanAddDate,  @MobileNo                
   WHILE @@FETCH_STATUS <> -1                
   BEGIN                
      BEGIN TRY                   
        INSERT INTO MailQSMS(UniqueKey, UniqueKeyName, StorerKey, R01Name, R01, R02Name, R02, R03Name, R03)                
        OUTPUT INSERTED.Qid INTO @mailQSMS                
        VALUES ( @ConsigneeKey, 'ConsigneeKey', @StorerKey, 'ConsigneeKey', @ConsigneeKey, 'AddDate', @LoadPlanAddDate, 'C_Phone1' , @MobileNo)                
        SET @RowCount = @@ROWCOUNT                
      END TRY                
      BEGIN CATCH                
         SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');                  
         SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);                  
         SET @Err = @@ERROR + 50000;                  
         EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''                  
         INSERT ALERT(AlertKey, ModuleName, AlertMessage, Severity, NotifyId, Status, ResolveDate, Resolution, Storerkey, UCCNo, UOMQty, Qty, ID  )                   
         VALUES   (@c_AlertKey,ISNULL(OBJECT_NAME(@@PROCID),''),@ConsigneeKey, @ErrSeverity, ISNULL(HOST_NAME(),''),@Err, '', ISNULL(@ConsigneeKey, ''), @StorerKey, @Qid, @RowCount, DATEDIFF(s,@dBegin,GETDATE()),LEFT(@ErrMsg,20));                  
         THROW @Err, @ErrMsg, 1;                
      END CATCH                
                     
      SELECT @Qid = Qid FROM @mailQSMS                
             
      IF(@Debug =1)                
      BEGIN                 
        SELECT @RowCount 'No.RowCountSMSHeader', @Qid 'No.Qid'                
        SELECT * FROM MailQSMS (nolock) WHERE Qid = @Qid                
      END                
                
      SET @c_SMSBody=''            
      SET @c_SMSBody2 = ''             
      SET @TotalSumQriginalQty=''                
                
      IF (@RowCount > 0 AND ISNULL(@Qid, 0) > 0)               
      BEGIN             
         SELECT @GrandTotalSumQriginalQty = SUM (od.OriginalQty)             
         FROM  ORDERS o  WITH (NOLOCK)                
         JOIN ORDERDETAIL od WITH (NOLOCK) ON o.OrderKey = od.OrderKey                
         JOIN STORER c WITH (NOLOCK) ON o.ConsigneeKey = c.StorerKey                
         JOIN LoadPlanDetail lp WITH (NOLOCK) ON lp.OrderKey = o.OrderKey                
         JOIN LoadPlan l WITH (NOLOCK) ON l.LoadKey = o.LoadKey                
         WHERE o.StorerKey = @StorerKey                    
            AND o.ConsigneeKey = @ConsigneeKey            
            --AND o.[Status] = '9'        -- kocy02    
            AND o.Doctype = 'N'            
            AND o.[Type] <> 'Transfer'  
            AND FORMAT (l.AddDate, 'MM/dd') = @LoadPlanAddDate            
            
            
         DECLARE CUR_2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
         SELECT ISNULL(o.ExternOrderKey,''), SUM (od.OriginalQty), o.Orderkey                
         FROM  ORDERS o  WITH (NOLOCK)                
         JOIN ORDERDETAIL od WITH (NOLOCK) ON o.OrderKey = od.OrderKey                
         JOIN STORER c WITH (NOLOCK) ON o.ConsigneeKey = c.StorerKey                
         JOIN LoadPlanDetail lp WITH (NOLOCK) ON lp.OrderKey = o.OrderKey                
         JOIN LoadPlan l WITH (NOLOCK) ON l.LoadKey = o.LoadKey             
         WHERE o.StorerKey = @StorerKey                    
            AND o.ConsigneeKey = @ConsigneeKey            
            --AND o.[Status] = '9'        -- kocy02  
            AND o.Doctype = 'N'            
            AND o.[Type] <> 'Transfer'  
            AND FORMAT (l.AddDate, 'MM/dd') = @LoadPlanAddDate            
         GROUP BY ISNULL(o.ExternOrderKey,''), o.OrderKey            
            
         OPEN CUR_2                
         FETCH NEXT FROM CUR_2 INTO  @ExternOrderKey, @SumOriginalQty, @OrderKey                
         WHILE @@FETCH_STATUS <> -1                
         BEGIN              
            
            SET @concatenate = @ExternOrderKey + N', ' + @SumOriginalQty + N'件; '                    
            --SET @c_SMSBody +=  @ExternOrderKey + '， ' + @SumOriginalQty  + N'件; '                
            --SET @TotalSumQriginalQty = CAST(@TotalSumQriginalQty AS INT) + CAST(@SumOriginalQty AS INT)             
                        
             /*CN ALC SMS Platform sustain max 35 char only */            
            IF (LEN(@c_SMSBody) + LEN (@concatenate)) <=35               
            BEGIN             
                 SET @c_SMSBody += @concatenate            
                 SET @TotalSumQriginalQty += CAST (@SumOriginalQty AS INT)            
            END            
            ELSE  IF( LEN(@c_SMSBody2) + LEN (@concatenate) ) <=35            
            BEGIN             
                 SET @c_SMSBody2 += @concatenate            
                 SET @TotalSumQriginalQty += CAST (@SumOriginalQty AS INT)            
            END            
            ELSE             
            BEGIN            
                /*CN ALC SMS platform use json */            
               SET @cSQL = N'{'+N'"order_summary":"' + @LoadPlanAddDate + N'",'                     
                                  +N'"order_num":"' + @c_SMSBody +  N'",'            
                                  +N'"order_qty":"' + @c_SMSBody2 +  N'",'            
                                  +N'"total_qty":"' + @TotalSumQriginalQty + N'/' + @GrandTotalSumQriginalQty + N'"'                           
                                  +N'}'                 
              
                  --SET @cSQL = N'您好， 这里是利丰供应链管理 （中国） 有限公司，' + CHAR(13) +                
                  --            N'您的 ' + @LoadPlanAddDate + N' 的补货， 其订单及件数信息如下：' + CHAR(13) +                
                  --            @c_SMSBody + CHAR(13) +                
                  --            N'上述订单共' + @TotalSumQriginalQty + N'件，仓库正在装箱， 会尽快发出， 请等候， 谢谢！'             
                    
               SET @c_SMSBody = ''                  
               SET @c_SMSBody2 = ''            
               SET @c_SMSBody+= @concatenate            
            
               SET @TotalSumQriginalQty = 0            
               SET @TotalSumQriginalQty += CAST (@SumOriginalQty AS INT)            
            
               IF (@Debug =1)                
            BEGIN                 
                  SELECT @cSQL            
               END             
                           
               INSERT INTO [DTS].[DBMailQueue] ( mail_type, recipients, [subject], body , body_format, AddSource )                   
               OUTPUT INSERTED.mail_id INTO @DBMailQueue                  
               VALUES ( 'SMS', 'Support@xgate.com.hk', 'R'+REPLACE(CASE WHEN @Debug = 1 THEN '60108165210' ELSE @MobileNo END ,'+', '') , @cSQL, 'SMS_251066368' , OBJECT_NAME(@@PROCID) )                     
                                 
               SELECT @mail_id = mail_id FROM @DBMailQueue                
               UPDATE MailQSMS SET mail_id = @mail_id WHERE Qid = @Qid             
            END            
            
            BEGIN TRY                
               INSERT INTO MailQSMSDet (Qid, C01Name, C01, C02Name, C02 , OrderKey)                
               VALUES (@Qid, 'ExternOrderKey', @ExternOrderKey, 'SumOfOrignalQty', @SumOriginalQty, @OrderKey)                
               SET @RowCount = @@ROWCOUNT                
            END TRY                
            BEGIN CATCH                  
               SET @ErrMsg     = ISNULL(ERROR_MESSAGE(),'');                  
               SET @ErrSeverity = ISNULL(ERROR_SEVERITY(),0);                  
               SET @Err = @@ERROR + 50000;                  
               EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''                  
               INSERT ALERT(AlertKey, ModuleName, AlertMessage, Severity, NotifyId, Status, ResolveDate, Resolution, Storerkey, UCCNo, UOMQty, Qty, ID  )                   
               VALUES   (@c_AlertKey,ISNULL(OBJECT_NAME(@@PROCID),''),@ExternOrderKey, @ErrSeverity, ISNULL(HOST_NAME(),''),@Err, '', ISNULL(@ConsigneeKey, ''), 
                         @StorerKey, @TotalLoadKey, @RowCount, DATEDIFF(s,@dBegin,GETDATE()),LEFT(@ErrMsg,20));       
               THROW @Err, @ErrMsg, 1;                  
            END CATCH            
            
         FETCH NEXT FROM CUR_2 INTO @ExternOrderKey, @SumOriginalQty, @OrderKey                
         END                  
         CLOSE CUR_2                      
         DEALLOCATE CUR_2                
                 
         IF (@RowCount > 0 AND @Err = 0  AND ISNULL (@c_SMSBody, '') <> '' )                
         BEGIN                
            SET @cSQL = N'{'+N'"order_summary":"' + @LoadPlanAddDate + N'",'                     
                            +N'"order_num":"' + @c_SMSBody +  N'",'            
                            +N'"order_qty":"' + @c_SMSBody2 +  N'",'            
                            +N'"total_qty":"' + @TotalSumQriginalQty + N'/' + @GrandTotalSumQriginalQty + N'"'                           
                            +N'}'              
               
            --SET @cSQL = N'您好， 这里是利丰供应链管理 （中国） 有限公司，' + CHAR(13) +        
            --            N'您的 ' + @LoadPlanAddDate + N' 的补货， 其订单及件数信息如下：' + CHAR(13) +                
            --            @c_SMSBody + CHAR(13) +                
            --            N'上述订单共' + @TotalSumQriginalQty + N'件，仓库正在装箱， 会尽快发出， 请等候， 谢谢！'              
                        
            INSERT INTO [DTS].[DBMailQueue] ( mail_type, recipients, [subject], body , body_format, AddSource )                   
            OUTPUT INSERTED.mail_id INTO @DBMailQueue                  
            VALUES ( 'SMS', 'Support@xgate.com.hk', 'R'+REPLACE(CASE WHEN @Debug = 1 THEN '60108165210' ELSE @MobileNo END ,'+', '') , @cSQL, 'SMS_251066368' , OBJECT_NAME(@@PROCID) )                     
                              
            SELECT @mail_id = mail_id FROM @DBMailQueue                
            UPDATE MailQSMS SET mail_id = @mail_id WHERE Qid = @Qid              
             
            IF (@Debug =1)                
            BEGIN                
               SELECT @cSQL            
               SELECT @RowCount 'No.RowCountSMSDet',@Err 'No.Error'             
               SELECT * FROM MailQSMSDet (nolock) WHERE Qid = @Qid              
            END               
         END                                 
      END  -- end of (@RowCount > 0) AND ISNULL(@Qid, 0) > 0                
      ELSE                 
      BEGIN                 
         SELECT 'No @Qid'                
      END                
                
  FETCH NEXT FROM CUR_1 INTO  @ConsigneeKey, @LoadPlanAddDate, @MobileNo                
  END                  
  CLOSE CUR_1                      
  DEALLOCATE CUR_1                
                    
END -- end of SP 

GO