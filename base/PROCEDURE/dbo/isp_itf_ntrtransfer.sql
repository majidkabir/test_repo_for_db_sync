SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_ITF_ntrTransfer                                */
/* Creation Date: 22-Apr-2014                                           */
/* Copyright: LF                                                        */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Handling trigger points for Transfer's module.             */
/*           Including Transfer Header trigger points for Add & Update. */
/*                                                                      */
/* Input Parameters:   @c_TriggerName        - TriggerName              */
/*                     @c_SourceTable        - SourceTable              */
/*                     @c_FromStorerKey      - FromStorerKey            */
/*                     @c_ToStorerKey        - ToStorerKey              */
/*                     @c_TransferKey        - TransferKey              */
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
/*             - ntrTransferHeaderAdd                                   */
/*             - ntrTransferHeaderUpdate                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Date         Author    Ver.  Purposes                                */
/* DD-MMM-YYYY                                                          */
/* 23-Jun-2014  KTLOW     1.1   Add WSTRFLOG (KT01)                     */
/* 28-Oct-2014  MCTang    1.1   Add TRFFMLOG (MC01)                     */
/* 12-Jun-2015  KTLow     1.2   SOS#343129 - Insert Into Transmitlog2   */
/*                              (KT02)                                  */
/* 02-Jun-2016  MCTang    1.1   Add TRFFMLOGTN (MC02)                   */
/* 02-Jun-2016  MCTang    1.1   Add TRF2LOG(MC03)                       */
/* 24-Jan-2017  TLTING01  1.2   SET ANSI NULLS Option (tlting)          */
/* 02-Jun-2016  MCTang    1.1   Add TRF3LOG(MC04)                       */
/* 07-Dec-2020  KHChan    1.4   LFI-379 - Add WSTRFFMLOG (KH01)         */
/************************************************************************/

CREATE PROC [dbo].[isp_ITF_ntrTransfer]
            @c_TriggerName          nvarchar(120)
          , @c_SourceTable          nvarchar(60)
          , @c_FromStorerKey        nvarchar(15)
          , @c_ToStorerKey          nvarchar(15)
          , @c_TransferKey          nvarchar(10)
          , @b_Success              int           OUTPUT
          , @n_err                  int           OUTPUT
          , @c_errmsg               nvarchar(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   --SET ANSI_DEFAULTS OFF       --tlting
   SET ANSI_NULLS OFF            --tlting
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

   -- Transfer table
   DECLARE @c_Type                  nvarchar(12)
         , @c_ReasonCode            nvarchar(10)
         , @c_Status                nvarchar(10)
         , @c_Facility              nvarchar(5)

   SET @n_StartTCnt = @@TRANCOUNT 
   SET @n_continue = 1 
   SET @b_success = 0 
   SET @n_err = 0 
   SET @c_errmsg = '' 
/********************************************************/
/* Variables Declaration & Initialization - (End)       */
/********************************************************/

/*************************************************************************************/
/* Std - Verify Parameter variables, no values found, return to core program (Start) */
/*************************************************************************************/
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR 
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR 
      (ISNULL(RTRIM(@c_FromStorerKey),'') = '') OR 
      (ISNULL(RTRIM(@c_ToStorerKey),'') = '') OR 
      (ISNULL(RTRIM(@c_TransferKey),'') = '')
   BEGIN
      RETURN
   END

   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrTransferHeaderUpdate')
   BEGIN
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrTransferHeaderAdd')
      BEGIN
         RETURN
      END
   END

   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'TRANSFER')
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
      SELECT @c_Type        = ISNULL(RTRIM(TRANSFER.Type),'')
           , @c_ReasonCode  = ISNULL(RTRIM(TRANSFER.ReasonCode),'') 
           , @c_Status      = ISNULL(RTRIM(TRANSFER.Status),'') 
           , @c_Facility    = ISNULL(RTRIM(TRANSFER.Facility),'') 
        FROM TRANSFER WITH (NOLOCK) 
       WHERE TRANSFER.TransferKey = @c_TransferKey
   END 
/*************************************************************************************/
/* Std - Extract values for required variables (End)                                 */
/*************************************************************************************/

/********************************************/
/* Main Program (Start)                     */
/********************************************/
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
/***************************************************************************************************************************************/
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on TRANSFER & FromStorerKey - (Start)  */
/***************************************************************************************************************************************/
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)  
                   WHERE StorerKey   = @c_FromStorerKey 
                     AND SourceTable = @c_SourceTable
                     AND sValue      = '1' )
      BEGIN 
         DECLARE Cur_ITFTriggerConfig_TRFFrom CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT DISTINCT ConfigKey
                        , Facility
                        , Tablename
                        , RecordType
                        , RecordStatus
                        , sValue
                        , TargetTable
                        , StoredProc
            FROM ITFTriggerConfig WITH (NOLOCK) 
           WHERE StorerKey   = @c_FromStorerKey  
             AND SourceTable = @c_SourceTable
             AND sValue      = '1'

         OPEN Cur_ITFTriggerConfig_TRFFrom
         FETCH NEXT FROM Cur_ITFTriggerConfig_TRFFrom INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Added By YokeBeen on 17-Oct-2003 For NIKE Regional (NSC) Project - (SOS#15352)
            IF ISNULL(@c_ConfigFacility,'') = ''
            BEGIN 
               IF @c_ConfigKey = 'NIKEREGITF'
               BEGIN 
                  -- Only certain Reason Code require for interface 
                  IF EXISTS ( SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                               WHERE ListName = 'TRNReason' 
                                 AND Code = @c_ReasonCode AND Short = 'NSC' )
                  BEGIN 
                     GOTO AddIntoTransmitLog_FromStorerKey
                  END -- ReasonCode verification requires for interface - 'NIKEREGITF'
               END -- IF @c_ConfigKey = 'NIKEREGITF'
               -- MC01 - S
               ELSE IF (@c_ConfigKey = 'TRFFMLOG' OR @c_ConfigKey = 'TRFFMLOGTN' OR @c_ConfigKey = 'TRF3LOG')   --(MC02)  --(MC04)
               BEGIN 
                  GOTO AddIntoTransmitLog_FromStorerKey
               END -- IF @c_ConfigKey = 'TRFFMLOG'
               -- MC01 - E
               --(KH01) -S WSTRFFMLOG
               ELSE IF (@c_ConfigKey = 'WSTRFFMLOG')
               BEGIN 
                  GOTO AddIntoTransmitLog_FromStorerKey
               END -- IF @c_ConfigKey = 'WSTRFFMLOG'
               --(KH01) -E
            END -- IF ISNULL(@c_ConfigFacility,'') = ''

            GOTO Next_Record_FromStorerKey

/*************************************************************************************/
/* Records Insertion into selected TransmitLog table with FromStorerKey - (Start)    */
/*************************************************************************************/
   AddIntoTransmitLog_FromStorerKey:

            IF @c_TargetTable = 'NSCLOG'
            BEGIN
               EXEC ispGenNSCLog @c_Tablename, @c_TransferKey, '', @c_FromStorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68000
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into NSCLog Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END
            END -- IF @c_TargetTable = 'NSCLOG'
            -- MC01 - S
            ELSE IF @c_TargetTable = 'TRANSMITLOG3'
            BEGIN
               EXEC ispGenTransmitLog3 @c_Tablename, @c_TransferKey, @c_ReasonCode, @c_FromStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                  
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68001
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END 
            END -- IF @c_TargetTable = 'TRANSMITLOG3'
            -- MC01 - E
            --(KH01) - S
            ELSE IF @c_TargetTable = 'TRANSMITLOG2'
            BEGIN
               EXEC ispGenTransmitLog2 @c_Tablename, @c_TransferKey, @c_ReasonCode, @c_FromStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                  
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68001
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END 
            END -- IF @c_TargetTable = 'TRANSMITLOG2'
            --(KH01) - E
/*************************************************************************************/
/* Records Insertion into selected TransmitLog table with FromStorerKey - (End)      */
/*************************************************************************************/

   Next_Record_FromStorerKey:
            FETCH NEXT FROM Cur_ITFTriggerConfig_TRFFrom INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus
                                                            , @c_sValue, @c_TargetTable, @c_StoredProc
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE Cur_ITFTriggerConfig_TRFFrom
         DEALLOCATE Cur_ITFTriggerConfig_TRFFrom
      END -- SourceTable = 'TRANSFER' AND StorerKey = @c_FromStorerKey
/***************************************************************************************************************************************/
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on TRANSFER & FromStorerKey - (End)    */
/***************************************************************************************************************************************/

/***************************************************************************************************************************************/
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on TRANSFER & ToStorerKey - (Start)    */
/***************************************************************************************************************************************/
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)  
                   WHERE StorerKey   = @c_ToStorerKey 
                     AND SourceTable = @c_SourceTable
                     AND sValue      = '1' )
      BEGIN 
         DECLARE Cur_ITFTriggerConfig_TRFTo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT DISTINCT ConfigKey
                        , Facility
                        , Tablename
                        , RecordType
                        , RecordStatus
                        , sValue
                        , TargetTable
                        , StoredProc
            FROM ITFTriggerConfig WITH (NOLOCK) 
           WHERE StorerKey   = @c_ToStorerKey  
             AND SourceTable = @c_SourceTable
             AND sValue      = '1'

         OPEN Cur_ITFTriggerConfig_TRFTo
         FETCH NEXT FROM Cur_ITFTriggerConfig_TRFTo INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus
                                                       , @c_sValue, @c_TargetTable, @c_StoredProc

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF ISNULL(@c_ConfigFacility,'') = ''
            BEGIN 
               -- Added by Vicky on 08-July-2005 
               IF @c_ConfigKey = 'TRFLOG' OR @c_ConfigKey = 'TRF2LOG'  --(MC03)
               BEGIN 
                  GOTO AddIntoTransmitLog_ToStorerKey
               END -- IF @c_ConfigKey = 'TRFLOG'
               ELSE 
               -- Added by YokeBeen on 03-Nov-2010 (FBR#195034)
               IF @c_ConfigKey = 'WTNTRFLOG'
               BEGIN 
                  GOTO AddIntoTransmitLog_ToStorerKey
               END -- IF @c_ConfigKey = 'WTNTRFLOG'
               ELSE
               --KT01 - S
               IF @c_ConfigKey = 'WSTRFLOG'
               BEGIN 
                  GOTO AddIntoTransmitLog_ToStorerKey
               END -- IF @c_ConfigKey = 'TRFLOG'
               --KT01 - E
            END -- IF ISNULL(@c_ConfigFacility,'') = '' 

            GOTO Next_Record_ToStorerKey

/*************************************************************************************/
/* Records Insertion into selected TransmitLog table with FromStorerKey - (Start)    */
/*************************************************************************************/
   AddIntoTransmitLog_ToStorerKey:

            IF @c_TargetTable = 'TRANSMITLOG3'
            BEGIN
               EXEC ispGenTransmitLog3 @c_Tablename, @c_TransferKey, @c_ReasonCode, @c_ToStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                  
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68001
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END 
            END -- IF @c_TargetTable = 'TRANSMITLOG3'
            ELSE
            IF @c_TargetTable = 'WITRONLOG'
            BEGIN
               EXEC dbo.ispGenWitronLog @c_Tablename, @c_TransferKey, @c_ReasonCode, @c_ToStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
                  
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68002
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into WITRONLOG Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END 
            END -- IF @c_TargetTable = 'WITRONLOG'
            --(KT02) - Start
            ELSE IF @c_TargetTable = 'TRANSMITLOG2'
            BEGIN
               EXEC ispGenTransmitLog2 @c_Tablename, @c_TransferKey, @c_ReasonCode, @c_ToStorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                  
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68001
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                                  ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrTransfer) ( SQLSvr MESSAGE = ' + 
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO QUIT
               END 
            END -- IF @c_TargetTable = 'TRANSMITLOG2'
            --(KT02) - End
/*************************************************************************************/
/* Records Insertion into selected TransmitLog table with FromStorerKey - (End)      */
/*************************************************************************************/

   Next_Record_ToStorerKey:
            FETCH NEXT FROM Cur_ITFTriggerConfig_TRFTo INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus
                                                          , @c_sValue, @c_TargetTable, @c_StoredProc
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE Cur_ITFTriggerConfig_TRFTo
         DEALLOCATE Cur_ITFTriggerConfig_TRFTo
      END -- SourceTable = 'TRANSFER' AND StorerKey = @c_ToStorerKey
/***************************************************************************************************************************************/
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on TRANSFER & ToStorerKey - (End)      */
/***************************************************************************************************************************************/

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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrTransfer'

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