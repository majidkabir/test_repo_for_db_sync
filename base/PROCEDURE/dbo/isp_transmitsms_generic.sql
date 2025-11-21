SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************************/                
/* Stored Procedure: [isp_TransmitSMS_Generic]                                       */                
/* Creation Date:                                                                    */                
/* Copyright: IDS                                                                    */                
/* Written by: kelvinongcy                                                           */                
/*                                                                                   */                
/* Purpose: Sent SMS for shipped orders according respective StorerKey               */            
/*                                                                                   */                
/* Called By:                                                                        */                
/*                                                                                   */                
/* PVCS Version: 1.0                                                                 */                
/*                                                                                   */                
/* Version: 5.4                                                                      */                
/*                                                                                   */                
/* Data Modifications:                                                               */                
/*                                                                                   */                
/* Updates:                                                                          */                
/* Date        Author         Ver.  Purposes                                         */                
/* 2020-07-22  kelvinongcy    1.0   WMS-20867 enhance to support CN ALC SMS platform */ 
/*                                  use json pass parameter                          */
/*                                  (remark: each param sustain 35 char only)        */               
/*************************************************************************************/           
     
CREATE   PROCEDURE [dbo].[isp_TransmitSMS_Generic]               
(   
  @c_StorerKey NVARCHAR(15),      
  @c_LISTNAME  nvarchar(20),      
  @c_Code      NVARCHAR (20),   -- TRANSMITLOG3.tablename      
  @b_debug     BIT = 0   
 )              
AS                 
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF             
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF                
              
   DECLARE   @c_UniqueKey        NVARCHAR(15)  
            ,@c_UniqueKeyName    NVARCHAR(255)  
            ,@c_R01Name          nvarchar(255)      
            ,@c_R02Name          nvarchar(255)      
            ,@c_R03Name          nvarchar(255)      
            ,@c_R04Name          nvarchar(255)      
            ,@c_R05Name          nvarchar(255)      
            ,@c_R01Value         NVARCHAR(255)      
            ,@c_R02Value         NVARCHAR(255)          
            ,@c_R03Value         NVARCHAR(255)          
            ,@c_R04Value         NVARCHAR(255)          
            ,@c_R05Value         NVARCHAR(255)     
            ,@c_SMSInfo          NVARCHAR(max)          
            ,@c_Stmt             NVARCHAR(max)   
            ,@c_ExecStmt         NVARCHAR(max)  
            ,@c_CursorStmt       NVARCHAR(max)  
            ,@c_CursorParm       NVARCHAR(1000)  
            ,@c_SMSTemplateCode  NVARCHAR(25)  
            ,@c_SMSCountryPrefix NVARCHAR(5)  
            ,@c_Parm             nvarchar(100)      
            ,@n_mail_id          INT       
            ,@n_Err              INT          
            ,@n_ErrMsg           NVARCHAR(255)          
            ,@n_ErrSeverity      INT          
            ,@d_Begin            DATETIME          
            ,@n_RowCount         INT          
            ,@c_AlertKey         CHAR(18)       
        
              
   DECLARE @MailQSMS table( mail_id int NOT NULL)        
   IF OBJECT_ID('tempdb..#K','u') IS NOT NULL  DROP TABLE  #K;        
   IF OBJECT_ID('tempdb..#M','u') IS NOT NULL  DROP TABLE  #M;       
   CREATE TABLE #K ( key1 nvarchar(10) NOT NULL PRIMARY KEY )        
   CREATE TABLE #M (          
     UniqueKey     NVARCHAR(15),        
  R01Value      NVARCHAR(255),          
     R02Value      NVARCHAR(255),          
     R03Value      NVARCHAR(255),          
     R04Value      NVARCHAR(255),           
     R05Value      NVARCHAR(255),    
     SMSInfo       NVARCHAR(max),  -- store SMS info sent    
   )          
          
   SELECT @n_Err = 0, @n_ErrMsg = '', @n_ErrSeverity = 0        
      
   EXEC dbo.isp_GetCodeLkup @c_LISTNAME , @c_StorerKey, @c_Code, 'SMSOptions' /*Code2*/, @n_ErrMsg OUTPUT ,@n_Err OUTPUT        
   , '' /*Description*/, @c_SMSCountryPrefix OUTPUT /*Short*/, @c_SMSTemplateCode OUTPUT /*Long*/, @c_Stmt    OUTPUT /*Notes*/, '' /*Notes2*/        
   , @c_R01Name OUTPUT /*UDF01*/, @c_R02Name OUTPUT /*UDF02*/, @c_R03Name OUTPUT /*UDF03*/, @c_R04Name OUTPUT /*UDF04*/, @c_R05Name OUTPUT /*UDF05*/      
  
   EXEC dbo.isp_GetCodeLkup @c_LISTNAME, @c_StorerKey, @c_Code, 'CursorOptions' /*Code2*/, @n_ErrMsg OUTPUT ,@n_Err OUTPUT             --kocy02  
     , ''  /*Description*/, '' /*Short*/,  @c_UniqueKeyName OUTPUT   /*Long*/, @c_CursorStmt    OUTPUT /*Notes*/, ''   /*Notes2*/      
     , '' /*UDF01*/, '' /*UDF02*/, '' /*UDF03*/, '' /*UDF04*/, '' /*UDF05*/   
         
   --IF @c_Code = 'SOCFMSMS'      
   --BEGIN      
   --   INSERT #K SELECT key1      
   --   FROM TRANSMITLOG3 t WITH (nolock)      
   --   WHERE tablename = @c_Code      
   --   AND   key3  = @c_StorerKey      
   --   AND  transmitflag = '0'      
   --   GROUP BY key1      
   --END      
        
   IF @b_debug=1         
   BEGIN              
      SELECT '@c_CursorStmt'= @c_CursorStmt    
      SELECT '@c_Stmt'= @c_Stmt  
   END        
      
   SET @c_ExecStmt = N'DECLARE CUR_TransmitSMS CURSOR FAST_FORWARD READ_ONLY FOR ' +   
                     @c_CursorStmt  
     
    SET @c_CursorParm = N'@c_StorerKey nvarchar(15)'  
    EXEC sp_ExecuteSql  @c_ExecStmt, @c_CursorParm, @c_StorerKey  
          
   SELECT @n_Err = @@error          
   IF @n_Err <> 0          
   BEGIN          
      SET @n_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error when declare cursor ('+OBJECT_NAME(@@PROCID)+').'          
   END          
          
   OPEN CUR_TransmitSMS          
   FETCH NEXT FROM CUR_TransmitSMS INTO @c_UniqueKey               
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
    
      TRUNCATE TABLE #M      
      
      --UPDATE TRANSMITLOG3 SET transmitflag = '1' WHERE transmitflag = '0' --KH01        
      --AND tablename=@c_Code AND key1=@c_UniqueKey AND key3=@c_StorerKey       
                  
      BEGIN TRY   
         SET @c_Parm = '@c_StorerKey nvarchar(15), @c_UniqueKey nvarchar(15)'  
           
         INSERT INTO #M (UniqueKey, R01Value, R02Value, R03Value, R04Value, R05Value, SMSInfo)    
         EXEC sp_ExecuteSql @c_Stmt ,@c_Parm ,@c_StorerKey ,@c_UniqueKey        
         SET @n_RowCount = @@RowCount          
      END TRY          
      BEGIN CATCH          
         SET @n_ErrMsg     = ISNULL(ERROR_MESSAGE(),'');          
         SET @n_ErrSeverity = ISNULL(ERROR_SEVERITY(),0);          
         SET @n_Err = @@error + 50000;          
  
         EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''          
         INSERT ALERT(AlertKey, ModuleName, AlertMessage, Severity, NotifyId, Status, ResolveDate, Resolution, Storerkey, UOMQty, ID  )           
         VALUES   (@c_AlertKey,ISNULL(OBJECT_NAME(@@PROCID),''),@c_UniqueKey, @n_ErrSeverity, ISNULL(HOST_NAME(),''),@n_Err, DATEDIFF(s,@d_Begin,GETDATE()), ISNULL(@c_Stmt, ''), @c_StorerKey, @n_RowCount,LEFT(@n_ErrMsg,20));          
         THROW @n_Err, @n_ErrMsg, 1;          
      END CATCH             
              
      SELECT   @c_UniqueKey      = ISNULL (UniqueKey,'')      
               ,@c_R01Value      = ISNULL (R01Value, '')     -- this row for receipt name    
               ,@c_R02Value      = ISNULL (R02Value, '')     -- this row for mobile no      
               ,@c_R03Value      = ISNULL (R03Value, '')        
               ,@c_R04Value      = ISNULL (R04Value, '')       
               ,@c_R05Value   = ISNULL (R05Value, '')              
               ,@c_SMSInfo       = ISNULL  (SMSInfo, '')     -- this row for SMS body info    
      FROM #M      
            
      IF (@b_debug = 1)          
      BEGIN          
          SELECT * FROM #M          
          SELECT @n_RowCount 'No.RowCount'          
      END          
           
      IF @n_RowCount > 0          
      BEGIN           
        IF ISNULL(@c_R02Value,'')  <> ''      -- mobile no     
        BEGIN                       
            INSERT INTO [DTS].[DBMailQueue] ( mail_type      
            ,recipients      
            ,[subject]      
            ,[body]      
            ,[body_format]      
            ,[AddSource]       
            ) OUTPUT INSERTED.mail_id INTO @MailQSMS         
            VALUES ( 'SMS'      
            ,'Support@xgate.com.hk'      
            ,CASE WHEN @b_debug = 1 THEN  '60108165210'  ELSE @c_SMSCountryPrefix + @c_R02Value END  -- To sent out the SMS, infront MobileNo need put phone's number CountryCode.      
            ,@c_SMSInfo  -- SMS body    
            ,@c_SMSTemplateCode      
            , OBJECT_NAME(@@PROCID) )         
        
            SELECT @n_mail_id = mail_id FROM @MailQSMS        
              
            IF ISNULL (@n_mail_id, 0) > 0  
            BEGIN  
               INSERT INTO MailQSMS ( mail_id, UniqueKeyName, UniqueKey, StorerKey, R01Name, R01, R02Name, R02, R03Name, R03, R04Name, R04, R05Name, R05)        
               VALUES(  @n_mail_id       
               , @c_UniqueKeyName, @c_UniqueKey       
               , @c_StorerKey      
               , @c_R01Name, @c_R01Value         
               , @c_R02Name, @c_R02Value      
               , @c_R03Name, @c_R03Value      
               , @c_R04Name, @c_R04Value      
               , @c_R05Name, @c_R05Value )   
           END  
           ELSE      
           BEGIN      
               SELECT  'No @n_mail_id'      
           END      
                  
            --UPDATE TRANSMITLOG3 SET transmitflag = '9' WHERE transmitflag = '1'       
            --AND tablename=@c_Code AND key1=@c_UniqueKey AND key3=@c_StorerKey       
        END        
     END      
  
           
   FETCH NEXT FROM CUR_TransmitSMS INTO  @c_UniqueKey               
   END          
   CLOSE CUR_TransmitSMS              
   DEALLOCATE CUR_TransmitSMS           
            
END  

GO