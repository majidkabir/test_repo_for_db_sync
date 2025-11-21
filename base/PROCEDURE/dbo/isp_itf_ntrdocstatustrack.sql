SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_ITF_ntrDocStatusTrack                          */
/* Creation Date: 20-Jun-2014                                           */
/* Copyright: LF                                                        */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose:  Handling trigger points for DocStatusTrack's module.       */
/*           Including DocStatusTrack Header trigger points for Add &   */
/*           Update.                                                    */
/*                                                                      */
/* Input Parameters:   @c_TriggerName        - TriggerName              */
/*                     @c_SourceTable        - SourceTable              */
/*                     @c_StorerKey          - StorerKey                */
/*                     @n_RowRef             - RowRef                   */
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
/*             - ntrDocStatusTrackUpdate                                */
/*             - ntrDocStatusTrackAdd                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Date         Author    Ver.  Purposes                                */
/* 19-Aug-2015  MCTang    1.1   Enhance Performace reduce loop (MC01)   */
/* 24-Jan-2017  TLTING01  1.2   SET ANSI NULLS Option                   */
/* 12-Jul-2017  MCTang    1.3   Add OTMITF (MC02)                       */
/* 09-Oct-2017  MCTang    1.3   Enhancement AddTrigger performance(MC03)*/
/************************************************************************/

CREATE PROC [dbo].[isp_ITF_ntrDocStatusTrack]
            @c_TriggerName          nvarchar(120)
          , @c_SourceTable          nvarchar(60)
          , @c_StorerKey            nvarchar(15)
          , @n_RowRef               int
          , @b_ColumnsUpdated       VARBINARY(1000)
          , @b_Success              int           OUTPUT
          , @n_Err                  int           OUTPUT
          , @c_ErrMsg               nvarchar(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF         -- tlting
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/********************************************************/
/* Variables Declaration & Initialization - (Start)     */
/********************************************************/
   DECLARE @n_Continue              int  
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

   -- Working Table
   DECLARE @c_DST_Type              nvarchar(12)
         , @c_DST_Status            nvarchar(10)
         , @c_DST_Finalized         nvarchar(10)
         , @c_Facility              nvarchar(5)
         , @c_Delimeter             char(1)
         , @n_StartPOS              int
         , @n_ValLen                int
         , @c_FieldName             nvarchar(50)
         , @c_Data                  nvarchar(100)
         , @c_DocTableName          nvarchar(30)    --(MC02)

   SET @n_StartTCnt = @@TRANCOUNT 
   SET @n_Continue = 1 
   SET @b_success = 0 
   SET @n_Err = 0 
   SET @c_ErrMsg = '' 
   SET @c_Delimeter = '|'
   SET @c_DocTableName = ''                        --(MC02)
/********************************************************/
/* Variables Declaration & Initialization - (End)       */
/********************************************************/

/*************************************************************************************/
/* Std - Verify Parameter variables, no values found, return to core program (Start) */
/*************************************************************************************/
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR 
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR 
      (ISNULL(RTRIM(@c_StorerKey),'')   = '') OR 
      (ISNULL(RTRIM(@n_RowRef),0)       = 0)
   BEGIN
      RETURN
   END

   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrDocStatusTrackUpdate')
   BEGIN
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrDocStatusTrackAdd')
      BEGIN
         RETURN
      END
   END

   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'DocStatusTrack')
   BEGIN
      RETURN
   END
/*************************************************************************************/
/* Std - Verify Parameter variables, no values found, return to core program (End)   */
/*************************************************************************************/


/*************************************************************************************/
/* Std - Extract values for required variables (Start)                               */
/*************************************************************************************/
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT @c_DST_Type      = ISNULL(RTRIM(TableName),'')
           , @c_DST_Finalized = ISNULL(RTRIM(Finalized),'') 
           , @c_DST_Status    = ISNULL(RTRIM(DOCStatus),'')
           , @c_DocTableName  = ISNULL(RTRIM(TableName),'')        --(MC02)
        FROM DocStatusTrack WITH (NOLOCK) 
       WHERE DocStatusTrack.RowRef = @n_RowRef
   END 
/*************************************************************************************/
/* Std - Extract values for required variables (End)                                 */
/*************************************************************************************/

/********************************************/
/* Main Program (Start)                     */
/********************************************/
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM  ITFTriggerConfig WITH (NOLOCK)    
                  WHERE StorerKey   = @c_StorerKey   
                  AND   SourceTable = @c_SourceTable  
                  AND   sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         --(MC01) - S
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
         AND   StoredProc  <> ''
         UNION
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
         WHERE StorerKey    = @c_StorerKey  
         AND   SourceTable  = @c_SourceTable
         AND   sValue       = '1'
         AND   StoredProc   = ''
         AND   RecordType   = @c_DST_Type
         AND   RecordStatus = CASE WHEN UpdatedColumns = 'Finalized' THEN @c_DST_Finalized ELSE @c_DST_Status END

         /*
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
         */
         --(MC01) - E

         OPEN Cur_ITFTriggerConfig
         FETCH NEXT FROM Cur_ITFTriggerConfig INTO @c_ConfigKey
                                                 , @c_ConfigFacility
                                                 , @c_Tablename
                                                 , @c_RecordType
                                                 , @c_RecordStatus
                                                 , @c_sValue
                                                 , @c_TargetTable
                                                 , @c_StoredProc
                                                 , @c_UpdatedColumns 

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            --PRINT '@c_ConfigKey: ' + @c_ConfigKey
            --PRINT '@c_UpdatedColumns: ' + @c_UpdatedColumns  

            IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrDocStatusTrackUpdate'      --(MC03)
            BEGIN 
               IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM 
                                dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                                WHERE COLUMN_NAME IN (
                                                SELECT ColValue 
                                                FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))
                  BEGIN
                     --PRINT 'Not Exists, GET_NEXT_Record '
                     GOTO GET_NEXT_Record
                  END 
               END
            END

            SET @b_Success = 0

            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               EXEC sys.sp_executesql @c_StoredProc, N'@n_RowRef INT, @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @n_RowRef, 
                           @b_Success OUTPUT, 
                           @n_err     OUTPUT, 
                           @c_errmsg  OUTPUT 
            END
            ELSE
            BEGIN
               IF (@c_RecordType <> '' AND (@c_RecordType = @c_DST_Type)) AND
                  ( (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_DST_Status) AND (UPPER(@c_UpdatedColumns) = 'DOCStatus'))               --(MC03)
                     OR (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_DST_Finalized) AND (UPPER(@c_UpdatedColumns) = 'Finalized'))        --(MC03)
                  ) 
                  --( (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_DST_Status)) OR (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_DST_Finalized)) )   --(MC03)
               BEGIN 
                  SET @b_Success = 1
               END 
            END

            IF @b_Success = 1
            BEGIN
               /*************************************************************************************/
               /* Records Insertion into selected TransmitLog table with StorerKey - (Start)        */
               /*************************************************************************************/
               IF @c_TargetTable = 'TRANSMITLOG3'
               BEGIN
                  EXEC ispGenTransmitLog3 @c_Tablename, @n_RowRef, '', @c_StorerKey, ''
                                        , @b_success OUTPUT
                                        , @n_Err OUTPUT
                                        , @c_ErrMsg OUTPUT
                     
                  IF @b_success <> 1
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 68001
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrDocStatusTrack) ( SQLSvr MESSAGE = ' + 
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '
                     GOTO QUIT
                  END 
               END -- IF @c_TargetTable = 'TRANSMITLOG3'
               ELSE IF @c_TargetTable = 'TRANSMITLOG2'
               BEGIN
                  EXEC ispGenTransmitLog2 @c_Tablename, @n_RowRef, '', @c_StorerKey, ''
                                        , @b_success OUTPUT
                                        , @n_Err OUTPUT
                                        , @c_ErrMsg OUTPUT
                     
                  IF @b_success <> 1
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 68001
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrDocStatusTrack) ( SQLSvr MESSAGE = ' + 
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '
                     GOTO QUIT
                  END 
               END -- IF @c_TargetTable = 'TRANSMITLOG2'

               /*************************************************************************************/
               /* Records Insertion into selected TransmitLog table with StorerKey - (End)          */
               /*************************************************************************************/
            END --IF @b_Success = 1

            GET_NEXT_Record:

            FETCH NEXT FROM Cur_ITFTriggerConfig INTO @c_ConfigKey
                                                    , @c_ConfigFacility
                                                    , @c_Tablename
                                                    , @c_RecordType
                                                    , @c_RecordStatus
                                                    , @c_sValue
                                                    , @c_TargetTable
                                                    , @c_StoredProc
                                                    , @c_UpdatedColumns 
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE Cur_ITFTriggerConfig
         DEALLOCATE Cur_ITFTriggerConfig
      END -- IF EXISTS @c_SourceTable  
   END -- IF @n_Continue = 1 OR @n_Continue = 2

   /* Handle ITC.StorerKey='ALL' which not able to configure detail in ITFTriggerConfig */   
   --(MC02) - S 
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
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrDocStatusTrackAdd'
         BEGIN  
            IF (@c_DocTableName = 'STSORDERS' AND @c_DST_Status in ('0','2','3','5','STSG','EDLD')) 
            OR (@c_DocTableName = 'STSPACK' AND @c_DST_Status = '9') 
            BEGIN
               EXEC ispGenOTMLog 'DSTADDOTM', @n_RowRef, @c_DST_Status, @c_StorerKey, ''
                               , @b_success   OUTPUT  
                               , @n_err       OUTPUT  
                               , @c_errmsg    OUTPUT 

               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  GOTO QUIT 
               END
            END
         END -- IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrDocStatusTrackAdd'
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
      /********************************************/  
      /* OTMITF (End)                             */  
      /********************************************/ 

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

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'isp_ITF_ntrDocStatusTrack'

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