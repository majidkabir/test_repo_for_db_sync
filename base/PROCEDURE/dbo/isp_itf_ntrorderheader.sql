SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store Procedure:  isp_ITF_ntrOrderHeader                             */    
/* Creation Date: 07-Aug-2014                                           */    
/* Copyright: LF                                                        */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:  Handling trigger points for Orders's module.               */    
/*           Including Orders Header trigger points for Add & Update.   */    
/*                                                                      */    
/* Output Parameters:  @b_Success                                       */    
/*                     @n_err                                           */    
/*                     @c_errmsg                                        */    
/*                                                                      */    
/* Return Status:  @b_Success = 0 or 1                                  */    
/*                                                                      */    
/* Usage:  StorerConfig & Trigger Points verification & update on       */    
/*         configuration table - ITFTriggerConfig.                      */    
/*                                                                      */    
/* Called By:  Trigger/Store Procedure.                                 */    
/*             - ntrOrderHeaderAdd                                      */    
/*             - ntrOrderHeaderUpdate                                   */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/* Date         Author    Ver.  Purposes                                */    
/* 18-Aug-2014  MCTang    1.8   Enhance Generaic Trigger for Interface  */  
/*                              when status feild Update (MC01)         */  
/* 22-Apr-2015  MCTang    1.8   Add OTMITF (MC02)                       */  
/* 06-May-2014  KTLow     1.8   SOS#336280 - Insert Into Transmitlog2   */  
/*                              (KT01)                                  */  
/* 20-May-2015  MCTang    1.8   ADD ntrOrderHeaderDelete (MC03)         */  
/* 21-Sep-2015  KTLow     1.9   ADD filter by RecordStatus (KT02)       */  
/* 10-Mar-2016  MCTang    2.0   Fix @b_Success Issues (MC04)            */  
/* 11-Jul-2016  MCTang    2.0   Add @c_TableName2 for OTMLOG (MC05)     */  
/* 24-Jan-2017  TLTING01  2.1   SET ANSI NULLS Option                   */  
/* 11-Apr-2018  MCTang    2.1   OTM add StorerConfig Check (MC06)       */  
/* 16-Jul-2018  MCTang    2.1   OTM add SOALLOCOTM & PKHCFMOTM (MC07)   */  
/* 04-Sep-2018  SWT01     2.2   Performance Tuning                      */  
/* 28-Sep-2018  TLTING    2.3   Performance tune                        */
/* 16-Nov-2018  MCTang    2.4   OTM Remove PKHCFMOTM (MC08)             */ 
/* 04-Feb-2019  MCTang    2.5   Add GVTITF (MC09)                       */
/* 13-Mar-2019  YTKuek    2.6   Add GVTITF Event (YT01)                 */
/* 06-Apr-2021  MCTang    2.7   Add SOPICKOTM (MC10)                    */
/* 22-Apr-2022  YTKuek    2.8   Add TNTITF (YT02)                       */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_ITF_ntrOrderHeader]    
            @c_TriggerName          nvarchar(120)    
          , @c_SourceTable          nvarchar(60)    
          , @c_OrderKey             nvarchar(10)    
          --, @b_ColumnsUpdated       VARBINARY(1000)  
          , @c_ColumnsUpdated       VARCHAR(500)              --(MC01)  
          , @b_Success              int           OUTPUT    
          , @n_err                  int           OUTPUT    
          , @c_errmsg               nvarchar(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF     -- TLTING01  
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF (ISNULL(RTRIM(@c_ColumnsUpdated),'') = '') AND @c_TriggerName = 'ntrOrderHeaderUpdate'
   BEGIN    
      RETURN    
   END    
        
   -- SWT01 Start  
   DECLARE @t_ColUpdate TABLE (  
      SeqNo    INT,   
      ColValue NVARCHAR(200) not null 
      PRIMARY KEY CLUSTERED ( ColValue )    )  

   IF CHARINDEX(',', @c_ColumnsUpdated) > 0   
   BEGIN  
      INSERT INTO @t_ColUpdate   (SeqNo, ColValue)
      SELECT SeqNo, ColValue  
      FROM dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)              
   END  
   ELSE   
   BEGIN  
    INSERT INTO @t_ColUpdate (SeqNo, ColValue)  
    VALUES (0, @c_ColumnsUpdated)   
   END  
  
   DECLARE @t_ColConfig TABLE (  
      SeqNo    INT,   
      ColValue NVARCHAR(200) not null 
      PRIMARY KEY CLUSTERED ( ColValue )   )  
   -- SWT01 End   
          
   /********************************************************/    
   /* Variables Declaration & Initialization - (Start)     */    
   /********************************************************/    
   DECLARE @n_continue              int      
         , @n_StartTCnt             int     -- Holds the current transaction count    
    
   -- ITFTriggerConfig table    
   DECLARE @c_ConfigKey             nvarchar(30)    
         , @c_Tablename             nvarchar(30)    
         , @c_Tablename2            nvarchar(30)  -- (MC05)  
         , @c_RecordType            nvarchar(10)    
         , @c_RecordStatus          nvarchar(10)    
         , @c_sValue                nvarchar(10)    
         , @c_TargetTable           nvarchar(60)    
         , @c_StoredProc            nvarchar(200)    
         , @c_ConfigFacility        nvarchar(5)  
         , @c_UpdatedColumns        NVARCHAR(250)      
    
   -- ORDERS table    
   DECLARE @c_StorerKey             nvarchar(15)    
         , @c_ReasonCode            nvarchar(10)    
         , @c_Status                nvarchar(10)    
         , @c_Facility              nvarchar(5)  
         , @c_Key1                  NVARCHAR(10)  
         , @c_Key2                  NVARCHAR(5)  
         , @c_SOStatus              NVARCHAR(10)     
         , @c_Authority_OTMLTF      NVARCHAR(1)    -- (MC02)    
    
   SET @n_StartTCnt = @@TRANCOUNT     
   SET @n_continue = 1     
   SET @b_success = 0     
   SET @n_err = 0     
   SET @c_errmsg = ''     
   SET @c_Authority_OTMLTF = ''                    --(MC02)      
   /********************************************************/    
   /* Variables Declaration & Initialization - (End)       */    
   /********************************************************/    
    
   /*************************************************************************************/    
   /* Std - Verify Parameter variables, no values found, return to core program (Start) */    
   /*************************************************************************************/    
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR     
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR           
      (ISNULL(RTRIM(@c_OrderKey),'') = '')    
   BEGIN    
      RETURN    
   END    
    
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrOrderHeaderUpdate')    
   BEGIN    
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrOrderHeaderAdd')    
      BEGIN    
         IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrOrderHeaderDelete')         --(MC03)  
         BEGIN  
            RETURN    
         END  
      END    
   END    
    
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'ORDERS')    
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
      IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderDelete'  
      BEGIN  
         SELECT @c_StorerKey   = ISNULL(RTRIM(StorerKey),'')    
              , @c_Status      = ISNULL(RTRIM(Status),'')     
              , @c_Facility    = ISNULL(RTRIM(Facility),'')     
              , @c_SOStatus    = ISNULL(RTRIM(SOSTATUS),'')  
          FROM DEL_ORDERS WITH (NOLOCK)     
         WHERE OrderKey = @c_OrderKey    
      END  
      ELSE  
      BEGIN  
         SELECT @c_StorerKey   = ISNULL(RTRIM(ORDERS.StorerKey),'')    
              , @c_Status      = ISNULL(RTRIM(ORDERS.Status),'')     
              , @c_Facility    = ISNULL(RTRIM(ORDERS.Facility),'')     
              , @c_SOStatus    = ISNULL(RTRIM(ORDERS.SOSTATUS),'')  
          FROM ORDERS WITH (NOLOCK)     
         WHERE ORDERS.OrderKey = @c_OrderKey    
      END  
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
         DECLARE Cur_ITFTriggerConfig_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
         SELECT  DISTINCT ConfigKey    
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
    
         OPEN Cur_ITFTriggerConfig_Order    
         FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus    
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns     
    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN   
          -- SWT01 Start  
            DELETE @t_ColConfig  
            IF CHARINDEX(',', @c_UpdatedColumns) > 0   
            BEGIN  
               INSERT INTO @t_ColConfig  (SeqNo, ColValue) 
               SELECT SeqNo, ColValue  
               FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)              
            END  
            ELSE   
            BEGIN  
             INSERT INTO @t_ColConfig (SeqNo, ColValue)  
             VALUES (0, @c_UpdatedColumns)   
            END  
            -- SWT01 End  
                 
            IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate'  
            BEGIN   
               --PRINT '@c_ConfigKey: ' + @c_ConfigKey  
               --PRINT '@c_UpdatedColumns: ' + @c_UpdatedColumns    
               IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''  
               BEGIN  
                  -- SWT01  
                  IF NOT EXISTS(SELECT 1 FROM @t_ColUpdate  
                                WHERE ColValue IN (SELECT ColValue FROM @t_ColConfig))    
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
                 
               EXEC sys.sp_executesql @c_StoredProc, N'@c_OrderKey NVARCHAR(10), @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',  
                           @c_OrderKey,   
                           @b_Success OUTPUT,   
                           @n_err     OUTPUT,   
                           @c_errmsg  OUTPUT   
            END  
            ELSE  
            BEGIN  
               --(KT02) - Start  
               --SET @b_Success = 1  
               SET @b_success = 0   --(MC04)  
  
               IF (@c_RecordStatus <> '' AND @c_RecordStatus = @c_Status AND UPPER(@c_UpdatedColumns) = 'STATUS') OR    
                  (@c_RecordStatus <> '' AND @c_RecordStatus = @c_SOStatus AND UPPER(@c_UpdatedColumns) = 'SOSTATUS' )    
               BEGIN    
                  SET @b_Success = 1  
               END  
               --(KT02) - End  
            END  
     
            IF @b_Success = 1  
            BEGIN  
               IF @c_ConfigKey = 'WSSTSLOG'  
               BEGIN  
                  --SET @c_key1 = @c_OrderKey  
                  SET @c_key2 = @c_Status  
               END  
                 
               IF @c_ConfigKey = 'WSSOSTSLOG'  
               BEGIN  
                  --SET @c_key1 = @c_OrderKey  
                  SET @c_key2 = @c_SOStatus  
               END  
   
               IF @c_TargetTable = 'TRANSMITLOG3'     
               BEGIN    
                  EXEC ispGenTransmitLog3 @c_Tablename, @c_OrderKey, @c_Key2, @c_StorerKey, ''    
                                          , @b_success OUTPUT    
                                          , @n_err OUTPUT    
                                          , @c_errmsg OUTPUT    
                         
                  IF @b_success <> 1    
                  BEGIN    
                     SET @n_continue = 3    
                     SET @n_err = 68001    
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
                                     ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrOrderHeader) ( SQLSvr MESSAGE = ' +     
                                     ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
                     GOTO QUIT    
                  END     
               END -- IF @c_TargetTable = 'TRANSMITLOG3'    
  
               --(KT01) - Start  
               IF @c_TargetTable = 'TRANSMITLOG2'     
               BEGIN    
                  EXEC ispGenTransmitLog2 @c_Tablename, @c_OrderKey, @c_Key2, @c_StorerKey, ''    
                                          , @b_success OUTPUT    
                                          , @n_err OUTPUT    
                                          , @c_errmsg OUTPUT    
                         
                  IF @b_success <> 1    
                  BEGIN    
                     SET @n_continue = 3    
                     SET @n_err = 68001    
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +     
                                     ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrOrderHeader) ( SQLSvr MESSAGE = ' +     
                                     ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
                     GOTO QUIT    
                  END     
               END -- IF @c_TargetTable = 'TRANSMITLOG2'    
               --(KT01) - End                 
            END  
    
            Get_Next_Config:  
              
            FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus    
                                                            , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns     
         END -- WHILE @@FETCH_STATUS <> -1    
         CLOSE Cur_ITFTriggerConfig_Order    
         DEALLOCATE Cur_ITFTriggerConfig_Order    
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)     
       
   END -- IF @n_continue = 1 OR @n_continue = 2    
  
   /* Handle ITC.StorerKey='ALL' which not able to configure detail in ITFTriggerConfig */     
   --(MC02) - S   
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN   
  
      SET @c_Tablename2 = ''   --(MC05)  
  
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
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderAdd'  
         BEGIN    
   
          IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)                  --(MC06)  
                      WHERE STC.StorerKey = @c_Storerkey   
                      AND   STC.ConfigKey = 'SOADDOTM'  
                      AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenOTMLog 'SOADDOTM', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                               , @b_success   OUTPUT    
                               , @n_err       OUTPUT    
                               , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  
  
         END -- IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderAdd'  
         ELSE IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderDelete'             --(MC03)  
         BEGIN    
   
          IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)                  --(MC06)  
                      WHERE STC.StorerKey = @c_Storerkey   
                      AND   STC.ConfigKey = 'DELSOOTM'  
                      AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenOTMLog 'DELSOOTM', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                               , @b_success   OUTPUT    
                               , @n_err       OUTPUT    
                               , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  
         END -- IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderDelete'  
         ELSE   
         BEGIN  
            IF EXISTS(SELECT 1 FROM                                                                               
                      @t_ColUpdate                                                   
                      WHERE ColValue IN ('STATUS','SOSTATUS'))        
            BEGIN  
  
               SET @b_Success = 0  
  
               IF @c_Status = '5'   
               BEGIN  
                  SET @c_TableName = 'SOPNPOTM'  
                  --SET @c_TableName2 = 'PKHCFMOTM'      --(MC07)  --(MC08)
                  SET @c_TableName2 =  'SOPICKOTM'       --(MC10)
                  SET @b_Success = 1 
               END   
               ELSE IF @c_Status = '9'   
               BEGIN  
                  SET @c_TableName = 'SOCFMOTM'  
                  SET @c_TableName2 = 'SOSHPOTM'         --(MC05)  
                  SET @b_Success = 1  
               END  
               ELSE IF @c_Status = 'CANC' OR @c_SOStatus = 'CANC'  
               BEGIN  
                  SET @c_TableName = 'CANCSOOTM'  
                  SET @b_Success = 1  
               END  
               ELSE IF @c_Status = '2'   
               BEGIN  
                  SET @c_TableName = 'SOALLOCOTM'     --(MC07)  
                  SET @b_Success = 1  
               END  
  
               IF @b_Success = 1  
               BEGIN  
                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)      --(MC06)  
                              WHERE STC.StorerKey = @c_Storerkey   
                              AND   STC.ConfigKey = @c_Tablename  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                        EXEC ispGenOTMLog @c_Tablename, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                        , @b_success   OUTPUT    
                                        , @n_err       OUTPUT    
                                        , @c_errmsg    OUTPUT   
  
                        IF @b_success <> 1  
                        BEGIN  
                           SET @n_continue = 3  
                           GOTO QUIT   
                        END  
                  END  
  
                  --(MC05) - S  
                  IF @c_TableName2 <> ''  
                  BEGIN  
                     IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)   --(MC06)  
                                 WHERE STC.StorerKey = @c_Storerkey   
                                 AND   STC.ConfigKey = @c_TableName2  
                                 AND   STC.SValue    = '1' )  
                     BEGIN  
                        EXEC ispGenOTMLog @c_TableName2, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                          , @b_success   OUTPUT    
                                          , @n_err       OUTPUT    
                                          , @c_errmsg    OUTPUT   
  
                        IF @b_success <> 1  
                        BEGIN  
                           SET @n_continue = 3  
                           GOTO QUIT   
                        END  
                     END  
                  END  
                  --(MC05) - E  
               END -- IF @b_Success = 1  
            END -- ColValue IN ('STATUS','SOSTATUS')  
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate')    
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)      
      /********************************************/    
      /* OTMITF (End)                             */    
      /********************************************/   
  
      /********************************************/    
      /* GVTITF (START)                           */    
      /********************************************/   
      --(MC09) - S
      IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK) 
                  WHERE STC.StorerKey = @c_Storerkey   
                  AND   STC.ConfigKey = 'GVTITF'  
                  AND   STC.SValue    = '1' )                       
      BEGIN  
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderAdd'
         BEGIN  
            
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTSOADD'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenGVTLog 'GVTSOADD', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  

            --(YT01)-S
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTESOADD'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenGVTLog 'GVTESOADD' , @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  
            --(YT01)-E

                
         END
         ELSE IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate'
         BEGIN  
            IF EXISTS(SELECT 1 FROM                                                                               
                      @t_ColUpdate                                                   
                      WHERE ColValue IN ('STATUS','SOSTATUS'))        
            BEGIN  
               
               SET @b_Success = 0  
               SET @c_TableName  = ''  --(YT01)
               SET @c_TableName2 = ''  --(YT01)

               IF @c_Status = '5'   
               BEGIN  
                  SET @c_TableName = 'GVTSOPACK'  
                  SET @c_TableName2 = 'GVTESOPACK' --(YT01)
                  SET @b_Success = 1 
               END   

               IF @c_Status = '9'   
               BEGIN  
                  SET @c_TableName = 'GVTSOCFM'  
                  SET @b_Success = 1 
               END   

               --(YT01)-S
               IF @c_Status = 'CANC'   
               BEGIN  
                  SET @c_TableName = 'GVTESOCANC'  
                  SET @b_Success = 1 
               END  
               --(YT01)-E
  
               IF @b_Success = 1  
               BEGIN  
  
                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = @c_Storerkey   
                              AND   STC.ConfigKey = @c_Tablename  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenGVTLog @c_Tablename, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                     , @b_success   OUTPUT    
                                     , @n_err       OUTPUT    
                                     , @c_errmsg    OUTPUT   
  
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        GOTO QUIT   
                     END  
                  END   

                  --(YT01)-S
                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = @c_Storerkey   
                              AND   STC.ConfigKey = @c_TableName2  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenGVTLog @c_TableName2, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                     , @b_success   OUTPUT    
                                     , @n_err       OUTPUT    
                                     , @c_errmsg    OUTPUT   
  
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        GOTO QUIT   
                     END  
                  END 
                  --(YT01)-E

               END -- IF @b_Success = 1  
            END -- ColValue IN ('STATUS','SOSTATUS')  
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate')    
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
      --(MC09) - E        
      /********************************************/    
      /* GVTITF (End)                             */    
      /********************************************/   

      --(YT02)-S
      /********************************************/    
      /* TNTITF (START)                           */    
      /********************************************/   
      IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK) 
                  WHERE STC.StorerKey = 'ALL'   
                  AND   STC.ConfigKey = 'TNTITF'  
                  AND   STC.SValue    = '1' )                       
      BEGIN  
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderAdd'
         BEGIN  
            
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = 'ALL'   
                        AND   STC.ConfigKey = 'TNTORDEVENT0'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEVENT0', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = 'ALL'   
                        AND   STC.ConfigKey = 'TNTORDEOK'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEOK', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = 'ALL'   
                        AND   STC.ConfigKey = 'TNTORDBPO'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDBPO', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = 'ALL'   
                        AND   STC.ConfigKey = 'TNTORDEPK'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEPK', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = 'ALL'   
                        AND   STC.ConfigKey = 'TNTORDINO'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDINO', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 
         END
         ELSE IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate'
         BEGIN  
            IF EXISTS(SELECT 1 FROM                                                                               
                      @t_ColUpdate                                                   
                      WHERE ColValue IN ('STATUS','SOSTATUS'))        
            BEGIN  
               
               SET @b_Success = 0  
               SET @c_TableName  = '' 
               SET @c_TableName2 = '' 

               IF @c_Status = '1'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT1'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '2'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT2'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '3'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT3'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '4'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT4'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '5'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT5'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '6'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT6'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '9'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT9'  
                  SET @c_TableName2 = 'TNTORDTN'
                  SET @b_Success = 1 
               END 

               IF @c_Status = 'CANC'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENTCANC'  
                  SET @b_Success = 1 
               END 
  
               IF @b_Success = 1  
               BEGIN  
  
                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = 'ALL'   
                              AND   STC.ConfigKey = @c_Tablename  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenTNTLog @c_Tablename, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                     , @b_success   OUTPUT    
                                     , @n_err       OUTPUT    
                                     , @c_errmsg    OUTPUT   
  
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        GOTO QUIT   
                     END  
                  END   

                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = 'ALL'   
                              AND   STC.ConfigKey = @c_TableName2  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenTNTLog @c_TableName2, @c_OrderKey, @c_Status, @c_StorerKey, ''    
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
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate')    
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)     
      ELSE IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK) 
                       WHERE STC.StorerKey = @c_StorerKey
                       AND   STC.ConfigKey = 'TNTITF'  
                       AND   STC.SValue    = '1' ) 
      BEGIN
        IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderAdd'
         BEGIN  
            
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_StorerKey
                        AND   STC.ConfigKey = 'TNTORDEVENT0'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEVENT0', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END  

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_StorerKey
                        AND   STC.ConfigKey = 'TNTORDEOK'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEOK', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_StorerKey
                        AND   STC.ConfigKey = 'TNTORDBPO'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDBPO', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_StorerKey
                        AND   STC.ConfigKey = 'TNTORDEPK'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDEPK', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 

            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_StorerKey
                        AND   STC.ConfigKey = 'TNTORDINO'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               EXEC ispGenTNTLog 'TNTORDINO', @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                 , @b_success   OUTPUT    
                                 , @n_err       OUTPUT    
                                 , @c_errmsg    OUTPUT   
  
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT   
               END  
            END 
         END
         ELSE IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate'
         BEGIN  
            IF EXISTS(SELECT 1 FROM                                                                               
                      @t_ColUpdate                                                   
                      WHERE ColValue IN ('STATUS','SOSTATUS'))        
            BEGIN  
               
               SET @b_Success = 0  
               SET @c_TableName  = '' 
               SET @c_TableName2 = '' 

               IF @c_Status = '1'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT1'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '2'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT2'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '3'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT3'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '4'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT4'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '5'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT5'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '6'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT6'  
                  SET @b_Success = 1 
               END 

               IF @c_Status = '9'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENT9'  
                  SET @c_TableName2 = 'TNTORDTN'
                  SET @b_Success = 1 
               END 

               IF @c_Status = 'CANC'   
               BEGIN  
                  SET @c_TableName = 'TNTORDEVENTCANC'  
                  SET @b_Success = 1 
               END 
  
               IF @b_Success = 1  
               BEGIN  
  
                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = @c_StorerKey
                              AND   STC.ConfigKey = @c_Tablename  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenTNTLog @c_Tablename, @c_OrderKey, @c_Status, @c_StorerKey, ''    
                                     , @b_success   OUTPUT    
                                     , @n_err       OUTPUT    
                                     , @c_errmsg    OUTPUT   
  
                     IF @b_success <> 1  
                     BEGIN  
                        SET @n_continue = 3  
                        GOTO QUIT   
                     END  
                  END   

                  IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                              WHERE STC.StorerKey = @c_StorerKey
                              AND   STC.ConfigKey = @c_TableName2  
                              AND   STC.SValue    = '1' )  
                  BEGIN  
                     EXEC ispGenTNTLog @c_TableName2, @c_OrderKey, @c_Status, @c_StorerKey, ''    
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
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate')
      END     
      /********************************************/    
      /* TNTITF (End)                             */    
      /********************************************/   
      --(YT02)-E

   END -- IF @n_continue = 1 OR @n_continue = 2   
   --(MC02) - E  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrOrderHeader'    
    
  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    
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