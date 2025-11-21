SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_ConvertErrWCSToRDT                              */
/* Creation Date: 05 Nov 2015                                           */
/* Copyright: LFL                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Sub StorProc that translate WCS Respond Error to RDT        */
/*                                                                      */
/* Called By: isp_TCP_WCS_MsgProcess                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ConvertErrWCSToRDT]
     @c_CallerSP        NVARCHAR(50)   = ''  
   , @c_WCSReasonCode   NVARCHAR(10)   = ''  
   , @c_WCSErrMsg       NVARCHAR(250)  = ''  
   , @b_debug           INT            = '0'
   , @b_Success         INT            OUTPUT
   , @n_Err             INT            OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  OUTPUT


AS 
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   /*********************************************/
   /* Variables Declaration                     */
   /*********************************************/
   DECLARE @n_continue           INT                
         , @c_ExecStatements     NVARCHAR(4000)     
         , @c_ExecArguments      NVARCHAR(4000) 
         , @n_StartTCnt          INT

   DECLARE @c_MapWCSLoc          NVARCHAR(1)    --(TK01) translate WCS Location to WMS Location
         , @c_WCSLoc             NVARCHAR(10)   --(TK01)
         , @c_WMSLoc             NVARCHAR(10)   --(TK01)

   SET @n_StartTCnt              = @@TRANCOUNT
   SET @n_continue               = 1 
   SET @c_ExecStatements         = '' 
   SET @c_ExecArguments          = ''
   SET @b_Success                = 0
   SET @n_Err                    = 0
   SET @c_ErrMsg                 = ''
   SET @c_MapWCSLoc              = '1'
   SET @c_WCSLoc                 = ''
   SET @c_WMSLoc                 = ''

   /*********************************************/
   /* Validation                                */
   /*********************************************/   
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      SET @c_WCSReasonCode = ISNULL(RTRIM(@c_WCSReasonCode),'')
      SET @c_WCSErrMsg     = ISNULL(RTRIM(@c_WCSErrMsg),'')

      IF ISNULL(@c_WCSReasonCode,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 58551  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^BlankRsnCode'
                       + ': WCSReasonCode cannot be empty. (isp_ConvertErrWCSToRDT)'  
         GOTO QUIT 
      END

      IF ISNULL(@c_WCSErrMsg,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 58552 
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^BlankErrMsg' 
                       + ': WCSErrMsg cannot be empty. (isp_ConvertErrWCSToRDT)'  
         GOTO QUIT 
      END
   END

   IF @b_debug = 1
   BEGIN
      SELECT 'INIT DATA'
            ,@c_CallerSP         [@c_CallerSP]
            ,@c_WCSReasonCode    [@c_WCSReasonCode]
            ,@c_WCSErrMsg        [@c_WCSErrMsg]
   END

   /*********************************************/
   /* Validation                                */
   /*********************************************/

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      IF @c_WCSReasonCode = 'F05'
      BEGIN
         
         IF CHARINDEX('Pallet exist at location R', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (Pallet exist at location R080200804) for PUTAWAY of pallet (50257508).
            SET @n_Err = 58553
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PltInASRSLoc' 
                          + ': Pallet exist at ASRS LOC (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
         ELSE IF CHARINDEX('Pallet exist at location P', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (Pallet exist at location P5100) for PUTAWAY of pallet (50395033).
            SET @c_WCSLoc = RTRIM(SUBSTRING(@c_WCSErrMsg, CHARINDEX('P', @c_WCSErrMsg, 15), 5))
            SELECT @c_WMSLoc = SHORT FROM Codelkup (NOLOCK) WHERE Code = @c_WCSLoc

            SET @n_Err = 58554
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PltInLoc(' + CASE WHEN @c_WMSLoc <> '' THEN @c_WMSLoc ELSE @c_WCSLoc END + ')' 
                          + ': Pallet exist in Location ' + CASE WHEN @c_WMSLoc <> '' THEN @c_WMSLoc ELSE @c_WCSLoc END + ' (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
         ELSE IF CHARINDEX('PalletId to long', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (PalletId to long) for PUTAWAY of pallet (ALVINFOO123).
            SET @n_Err = 58555
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PltIDTooLong' 
                          + ': Pallet ID too long (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END

      END
      ELSE IF @c_WCSReasonCode = 'F06'
      BEGIN
         IF CHARINDEX('From Pallet without putaway or move', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (From Pallet without putaway or move) for PLTSWAP of pallet (AIZA0028) to pallet (BS000006
            SET @n_Err = 58556
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PltHasNoTask' 
                          + ': Pallet has no task (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
         ELSE IF CHARINDEX('From Pallet is not outside', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (From Pallet is not outside) for PLTSWAP of pallet (12037704) to pallet (90030055).
            SET @n_Err = 58557
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PltNotOutside' 
                          + ': Pallet not OUTSIDE (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
      END
      ELSE IF @c_WCSReasonCode = 'F09'
      BEGIN
         IF CHARINDEX('Invalid From Location', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (Invalid From Location (CONVEYOR)) for MOVE of pallet (E413527253).
            SET @n_Err = 58558
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvldFrmWCSLoc' 
                          + ': Invalid From WCS Location (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
      END
      ELSE IF @c_WCSReasonCode = 'F10'
      BEGIN
         IF CHARINDEX('Missing from Location', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (Missing from Location) for PUTAWAY of pallet (50371402).
            SET @n_Err = 58559
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^MissingFrmLoc' 
                          + ': Missing From Location (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
      END
      ELSE IF @c_WCSReasonCode = 'F15'
      BEGIN
         IF CHARINDEX('Storer and SKU do not exist', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (Storer and SKU do not exist) for PUTAWAY of pallet (30030343).
            SET @n_Err = 58560
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^WCSSkuNotFound' 
                          + ': SKU not found in WCS (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
         ELSE IF CHARINDEX('No Route', @c_WCSErrMsg) > 0
         BEGIN
            --Exception (No Route) for MOVE of pallet (E443032550).
            SET @n_Err = 58561
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldWCSRoute' 
                           + ': Invalid WCS Route (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
      END
      ELSE IF @c_WCSReasonCode = 'F21'
      BEGIN
         --Exception (Task exist) for MOVE of pallet (12345678).
         IF CHARINDEX('Task exist', @c_WCSErrMsg) > 0
         BEGIN
            SET @n_Err = 58562
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^WCSTaskExist' 
                          + ': WCS Task Exist (isp_ConvertErrWCSToRDT)'
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         SET @n_Err = 58600
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^WCSRespndedErr' 
                        + ': WCS Responded error. ' + ISNULL(RTRIM(@c_WCSReasonCode), '') + '-' + ISNULL(RTRIM(@c_WCSErrMsg), '') 
         GOTO QUIT
      END
   END

   QUIT:

END

GO