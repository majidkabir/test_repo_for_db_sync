SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrReceipt                                 */  
/* Creation Date: 13-May-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose:  Handling trigger points for Receipt's module.              */  
/*           Including Receipt Header trigger points for Add & Update.  */  
/*                                                                      */  
/* Output Parameters:  @b_Success                                       */  
/*                     @n_Err                                           */  
/*                     @c_ErrMsg                                        */  
/*                                                                      */  
/* Return Status:  @b_Success = 0 or 1                                  */  
/*                                                                      */  
/* Usage:  StorerConfig & Trigger Points verification & update on       */  
/*         configuration table - ITFTriggerConfig.                      */  
/*                                                                      */  
/* Called By:  Trigger/Store Procedure.                                 */  
/*             - ntrReceiptHeaderAdd                                    */  
/*             - ntrReceiptHeaderUpdate                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */
/* 15-May-2015  KTLow     1.1   SOS#336290 - Web Service ITRN (KT01)    */  
/* 24-Jan-2017  TLTING01  2.1   SET ANSI NULLS Option                   */
/* 10-Aug-2017  MCTang    2.2   Customize for RCPTHM9LOG (MC01)         */
/* 11-Apr-2018  MCTang    2.1   OTM add StorerConfig Check (MC02)       */
/* 10-Apr-2019  YTKuek    2.3   Add GVTLog. (YT01)                      */
/* 10-Apr-2022  MCTang    2.4   Customize for RCPTHM9LOG (MC03)         */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ITF_ntrReceipt]  
            @c_TriggerName          nvarchar(120)  
          , @c_SourceTable          nvarchar(60)  
          , @c_ReceiptKey           nvarchar(10)  
          --, @b_ColumnsUpdated       VARBINARY(1000)
          , @c_ColumnsUpdated       VARCHAR(1000)              
          , @b_Success              int           OUTPUT  
          , @n_Err                  int           OUTPUT  
          , @c_ErrMsg               nvarchar(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  --tlting
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   /********************************************************/  
   /* Variables Declaration & Initialization - (Start)     */  
   /********************************************************/  
   DECLARE @n_continue              int    
         , @n_StartTCnt             int     -- Holds the current transaction count  
  
   -- ITFTriggerConfig table  
   DECLARE @c_ConfigKey             nvarchar(30)  
         , @c_Tablename             nvarchar(30)  
         , @c_RecordType            nvarchar(10)  
         , @c_RecordStatus          nvarchar(10)  
         , @c_sValue                nvarchar(10)  
         , @c_TargetTable           nvarchar(60)  
         , @c_StoredProc            nvarchar(200)  
         , @c_ConfigFacility        nvarchar(5)
         , @c_UpdatedColumns        NVARCHAR(250)      
  
   -- Receipt Table  
   DECLARE @c_StorerKey             nvarchar(15)  
         , @c_ReasonCode            nvarchar(10)  
         , @c_Status                nvarchar(10)  
         , @c_Facility              nvarchar(5)
         , @c_ASNStatus             NVARCHAR(10)   
         , @c_Authority_OTMLTF      NVARCHAR(1) 
         , @c_DOCType               NVARCHAR(1)   
         , @c_Userdefine09          NVARCHAR(30)      --(MC01)
         , @c_Userdefine10          NVARCHAR(30)      --(MC01)
  
   SET @n_StartTCnt = @@TRANCOUNT   
   SET @n_continue = 1   
   SET @b_success = 0   
   SET @n_Err = 0   
   SET @c_ErrMsg = ''   
   SET @c_Authority_OTMLTF = ''     
   
   SET @c_Userdefine09  = ''        --(MC01)
   SET @c_Userdefine10  = ''        --(MC01)                
   /********************************************************/  
   /* Variables Declaration & Initialization - (End)       */  
   /********************************************************/  
  
   /*************************************************************************************/  
   /* Std - Verify Parameter variables, no values found, return to core program (Start) */  
   /*************************************************************************************/  
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR   
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR         
      (ISNULL(RTRIM(@c_ReceiptKey),'') = '')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrReceiptHeaderUpdate')  
   BEGIN  
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrReceiptHeaderAdd')  
      BEGIN  
         RETURN  
      END  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'RECEIPT')  
   BEGIN  
      RETURN  
   END  
   /*************************************************************************************/  
   /* Std - Verify Parameter variables, no values found, return to core program (End)   */  
   /*************************************************************************************/  
  
  
   /*************************************************************************************/  
   /* Std - Extract values for required variables (Start)                               */  
   /*************************************************************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @c_StorerKey   = ISNULL(RTRIM(Receipt.StorerKey),'')  
           , @c_Status      = ISNULL(RTRIM(Receipt.Status),'')   
           , @c_Facility    = ISNULL(RTRIM(Receipt.Facility),'')   
           , @c_ASNStatus   = ISNULL(RTRIM(Receipt.ASNStatus),'')
           , @c_DOCType     = ISNULL(RTRIM(Receipt.DocType),'')
      FROM   Receipt WITH (NOLOCK)   
      WHERE  Receipt.ReceiptKey = @c_ReceiptKey  
   END   
   /*************************************************************************************/  
   /* Std - Extract values for required variables (End)                                 */  
   /*************************************************************************************/  
  
/********************************************/  
/* Main Program (Start)                     */  
/********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
                  WHERE StorerKey   = @c_StorerKey   
                  AND   SourceTable = @c_SourceTable  
                  AND   sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig_Receipt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT DISTINCT  ConfigKey  
                        , Facility  
                        , Tablename  
                        , RecordType  
                        , RecordStatus  
                        , sValue  
                        , TargetTable  
                        , StoredProc
                        , UpdatedColumns  
         FROM  ITFTriggerConfig WITH (NOLOCK)   
         WHERE StorerKey   = @c_StorerKey    
         AND   SourceTable = @c_SourceTable  
         AND   sValue      = '1'  
  
         OPEN Cur_ITFTriggerConfig_Receipt  
         FETCH NEXT FROM Cur_ITFTriggerConfig_Receipt INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 

            SET @b_Success = 0 

            IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrReceiptHeaderUpdate'
            BEGIN 
               --PRINT '@c_ConfigKey: ' + @c_ConfigKey
               --PRINT '@c_UpdatedColumns: ' + @c_UpdatedColumns  
               IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
               BEGIN 
                  IF NOT EXISTS(SELECT 1 FROM                                                                             
                                dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                                
                                WHERE ColValue IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))    
                  BEGIN
                     --PRINT 'Not Exists'
                     GOTO Get_Next_Config
                  END 
               END
               ELSE
               BEGIN
                  GOTO Get_Next_Config
               END
            END
            
            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               SET @b_Success = 0 
               
               EXEC sys.sp_executesql @c_StoredProc, N'@c_ReceiptKey NVARCHAR(10), @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @c_ReceiptKey, 
                           @b_Success OUTPUT, 
                           @n_Err     OUTPUT, 
                           @c_ErrMsg  OUTPUT 
            END
            ELSE
            BEGIN
               IF (@c_RecordStatus <> '' AND @c_RecordStatus = @c_Status AND UPPER(@c_UpdatedColumns) = 'STATUS') OR
                  (@c_RecordStatus <> '' AND @c_RecordStatus = @c_ASNStatus AND UPPER(@c_UpdatedColumns) = 'ASNSTATUS' )
               BEGIN 
                  SET @b_Success = 1
               END 
            END
             
            IF @b_Success = 1
            BEGIN
               IF @c_TargetTable = 'TRANSMITLOG3'   
               BEGIN  

                  --(MC01) - S
                  IF @c_Tablename = 'RCPTHNM9L' OR @c_Tablename = 'RCPTHNM92L' 
                  BEGIN   
                     DECLARE Cur_ReceiptDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT ISNULL(RTRIM(Userdefine09),'')  
                          , ISNULL(RTRIM(Userdefine10),'')   
                     FROM   ReceiptDetail WITH (NOLOCK)   
                     WHERE  ReceiptKey = @c_ReceiptKey  

                     OPEN Cur_ReceiptDetail  
                     FETCH NEXT FROM Cur_ReceiptDetail INTO @c_Userdefine09, @c_Userdefine10 
  
                     WHILE @@FETCH_STATUS <> -1  
                     BEGIN 
                        IF ISNULL(RTRIM(@c_Userdefine09), '') <> ''
                        BEGIN
                           EXEC ispGenTransmitLog3 @c_Tablename, @c_ReceiptKey, @c_Userdefine09, @c_StorerKey, ''  
                                                   , @b_success OUTPUT  
                                                   , @n_Err OUTPUT  
                                                   , @c_ErrMsg OUTPUT  
                       
                           IF @b_success <> 1  
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_Err = 68001  
                              SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                              ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrReceipt) ( SQLSvr MESSAGE = ' +   
                                              ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                              GOTO QUIT  
                           END 
                        END

                        IF ISNULL(RTRIM(@c_Userdefine10), '') <> ''
                        BEGIN
                           EXEC ispGenTransmitLog3 @c_Tablename, @c_ReceiptKey, @c_Userdefine10, @c_StorerKey, ''  
                                                   , @b_success OUTPUT  
                                                   , @n_Err OUTPUT  
                                                   , @c_ErrMsg OUTPUT  
                       
                           IF @b_success <> 1  
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_Err = 68001  
                              SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                              ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrReceipt) ( SQLSvr MESSAGE = ' +   
                                              ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                              GOTO QUIT  
                           END 
                        END
                        FETCH NEXT FROM Cur_ReceiptDetail INTO @c_Userdefine09, @c_Userdefine10 
                     END -- WHILE @@FETCH_STATUS <> -1  
                     CLOSE Cur_ReceiptDetail  
                     DEALLOCATE Cur_ReceiptDetail  
                  END 
                  --(MC01) - E
                  ELSE
                  BEGIN
                     EXEC ispGenTransmitLog3 @c_Tablename, @c_ReceiptKey, @c_DOCType, @c_StorerKey, ''  
                                             , @b_success OUTPUT  
                                             , @n_Err OUTPUT  
                                             , @c_ErrMsg OUTPUT  
                       
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        SET @n_Err = 68001  
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                        ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrReceipt) ( SQLSvr MESSAGE = ' +   
                                        ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                        GOTO QUIT  
                     END  
                  END    
               END -- IF @c_TargetTable = 'TRANSMITLOG3'  

               --(KT01) - Start
               IF @c_TargetTable = 'TRANSMITLOG2'   
               BEGIN  
                  --(MC03) - S
                  IF @c_Tablename = 'WSRCHNM9L' OR @c_Tablename = 'WSRCHNM92L' 
                  BEGIN   
                     DECLARE Cur_ReceiptDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT ISNULL(RTRIM(Userdefine09),'')  
                          , ISNULL(RTRIM(Userdefine10),'')   
                     FROM   ReceiptDetail WITH (NOLOCK)   
                     WHERE  ReceiptKey = @c_ReceiptKey  

                     OPEN Cur_ReceiptDetail  
                     FETCH NEXT FROM Cur_ReceiptDetail INTO @c_Userdefine09, @c_Userdefine10 
  
                     WHILE @@FETCH_STATUS <> -1  
                     BEGIN 
                        IF ISNULL(RTRIM(@c_Userdefine09), '') <> ''
                        BEGIN
                           EXEC ispGenTransmitLog2 @c_Tablename, @c_ReceiptKey, @c_Userdefine09, @c_StorerKey, ''  
                                                   , @b_success OUTPUT  
                                                   , @n_Err OUTPUT  
                                                   , @c_ErrMsg OUTPUT  
                       
                           IF @b_success <> 1  
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_Err = 68001  
                              SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                              ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrReceipt) ( SQLSvr MESSAGE = ' +   
                                              ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                              GOTO QUIT  
                           END 
                        END

                        IF ISNULL(RTRIM(@c_Userdefine10), '') <> ''
                        BEGIN
                           EXEC ispGenTransmitLog2 @c_Tablename, @c_ReceiptKey, @c_Userdefine10, @c_StorerKey, ''  
                                                   , @b_success OUTPUT  
                                                   , @n_Err OUTPUT  
                                                   , @c_ErrMsg OUTPUT  
                       
                           IF @b_success <> 1  
                           BEGIN  
                              SET @n_continue = 3  
                              SET @n_Err = 68001  
                              SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                              ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrReceipt) ( SQLSvr MESSAGE = ' +   
                                              ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                              GOTO QUIT  
                           END 
                        END
                        FETCH NEXT FROM Cur_ReceiptDetail INTO @c_Userdefine09, @c_Userdefine10 
                     END -- WHILE @@FETCH_STATUS <> -1  
                     CLOSE Cur_ReceiptDetail  
                     DEALLOCATE Cur_ReceiptDetail  
                  END 
                  --(MC03) - E
                  ELSE
                  BEGIN

                     EXEC ispGenTransmitLog2 @c_Tablename, @c_ReceiptKey, @c_DOCType, @c_StorerKey, ''  
                                             , @b_success OUTPUT  
                                             , @n_Err OUTPUT  
                                             , @c_ErrMsg OUTPUT  
                       
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        SET @n_Err = 68001  
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                        ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrReceiptHeader) ( SQLSvr MESSAGE = ' +   
                                        ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                        GOTO QUIT  
                     END   
                  END
               END -- IF @c_TargetTable = 'TRANSMITLOG2'  
               --(KT01) - End               
            END
  
            Get_Next_Config:
            
            FETCH NEXT FROM Cur_ITFTriggerConfig_Receipt INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                            , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_Receipt  
         DEALLOCATE Cur_ITFTriggerConfig_Receipt  
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)   
   END -- IF @n_continue = 1 OR @n_continue = 2  

   /* Handle ITC.StorerKey='ALL' which not able to configure detail in ITFTriggerConfig */   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 

      /********************************************/  
      /* OTMITF (START)                           */  
      /********************************************/ 
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig ITC WITH (NOLOCK)    
                  JOIN   StorerConfig STC WITH (NOLOCK)                                                          
                  ON    (STC.StorerKey   = @c_StorerKey AND STC.ConfigKey = 'OTMITF' AND STC.SValue = '1' AND STC.ConfigKey = ITC.ConfigKey)   
                  WHERE  ITC.StorerKey   = 'ALL'   
                  AND    ITC.SourceTable = @c_SourceTable  
                  AND    ITC.sValue      = '1' )  
      BEGIN
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrReceiptHeaderAdd'
         BEGIN  
 
   	      IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)                   --(MC02)
   	                  WHERE STC.StorerKey = @c_Storerkey 
                        AND   STC.ConfigKey = 'ASNADDOTM'
   	                  AND   STC.SValue    = '1' )
            BEGIN
               EXEC ispGenOTMLog 'ASNADDOTM', @c_ReceiptKey, @c_DOCType, @c_StorerKey, ''  
                               , @b_success   OUTPUT  
                               , @n_Err       OUTPUT  
                               , @c_ErrMsg    OUTPUT 

               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  GOTO QUIT 
               END
            END
         END -- IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrReceiptHeaderAdd'
         ELSE 
         BEGIN
            IF EXISTS(SELECT 1 FROM                                                                             
                      dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                                 
                      WHERE ColValue IN ('STATUS','ASNStatus'))      
            BEGIN

               SET @b_Success = 0

               IF @c_ASNStatus = '9'
               BEGIN
                  SET @c_TableName = 'RCPTOTM'
                  SET @b_Success = 1
               END 
               ELSE IF @c_ASNStatus = 'CANC'
               BEGIN
                  SET @c_TableName = 'CANCASNOTM'
                  SET @b_Success = 1
               END

               IF @b_Success = 1
               BEGIN

   	            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)                   --(MC02)
   	                        WHERE STC.StorerKey = @c_Storerkey 
                              AND   STC.ConfigKey = @c_Tablename
   	                        AND   STC.SValue    = '1' )
                  BEGIN
                     EXEC ispGenOTMLog @c_Tablename, @c_ReceiptKey, @c_DOCType, @c_StorerKey, ''  
                                     , @b_success   OUTPUT  
                                     , @n_Err       OUTPUT  
                                     , @c_ErrMsg    OUTPUT 

                     IF @b_success <> 1
                     BEGIN
                        SET @n_continue = 3
                        GOTO QUIT 
                     END
                  END
               END -- IF @b_Success = 1
            END -- ColValue IN ('STATUS','ASNStatus')
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrReceiptHeaderUpdate')  
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
      /********************************************/  
      /* OTMITF (End)                             */  
      /********************************************/ 

      /********************************************/    
      /* GVTITF (START)                           */    
      /********************************************/   
      --(YT01) - S
      IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK) 
                  WHERE STC.StorerKey = @c_Storerkey   
                  AND   STC.ConfigKey = 'GVTITF'  
                  AND   STC.SValue    = '1' )                       
      BEGIN  

        IF EXISTS(SELECT 1 FROM                                                                             
                    dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                                 
                    WHERE ColValue IN ('STATUS','ASNStatus'))        
        BEGIN  
  
            SET @b_Success = 0  
				
            IF @c_Status = '0'
            BEGIN
			      IF @c_ASNStatus = '1'
			      BEGIN
				      SET @c_Tablename = 'GVTEASNREC'
				      SET @b_Success = 1
			      END
            END

            IF @c_Status = '9'   
            BEGIN  
                SET @c_TableName = 'GVTEASNCFM'  
                SET @b_Success = 1 
            END   
  
            IF @b_Success = 1  
            BEGIN  
  
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = @c_Tablename  
                        AND   STC.SValue    = '1' )  
                BEGIN  
                    EXEC ispGenGVTLog @c_Tablename, @c_ReceiptKey, @c_Status, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                    IF @b_success <> 1  
                    BEGIN  
                    SET @n_continue = 3  
                    GOTO QUIT   
                    END  
                END   
            END -- IF @b_Success = 1  
        END -- ColValue IN ('STATUS','SOSTATUS')  
   
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
      --(YT01) - E        
      /********************************************/    
      /* GVTITF (End)                             */    
      /********************************************/ 

   END -- IF @n_continue = 1 OR @n_continue = 2 
/********************************************/  
/* Main Program (End)                       */  
/********************************************/  
  
/********************************************/  
/* Std - Error Handling (Start)             */  
/********************************************/  
QUIT:  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN TRAN  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'isp_ITF_ntrReceipt'  
  
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
/********************************************/  
/* Std - Error Handling (End)               */  
/********************************************/  
END -- procedure  

GO