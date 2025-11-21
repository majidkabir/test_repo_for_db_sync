SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_FinalizeChannelTransfer                             */
/* Creation Date: 01-OCT-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Channel Inventory Transfer                                  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 23-JUL-2019  Wan01   1.1   ChannelInventoryMgmt use nspGetRight2     */
/* 16-Aug-2021  NJOW01  1.2   WMS-17740 Allow finalize zero qty for itf */
/* 19-May-2021  WLChooi 1.3   WMS-17048 Add Channel Transfer Extended   */
/*                            Validation (WL01)                         */
/* 11-Oct-2021  LZG     1.4   JSM-24637 - Revised error message (ZG01)  */
/************************************************************************/
CREATE PROC [dbo].[isp_FinalizeChannelTransfer]
      @c_ChannelTransferKey         NVARCHAR(10)
   ,  @c_ChannelTransferLineNumber  NVARCHAR(5) = ''
   ,  @b_Success     INT   OUTPUT
   ,  @n_Err         INT   OUTPUT
   ,  @c_ErrMsg      NVARCHAR(255)  OUTPUT      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
	
   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @n_Count              INT
         , @n_EmptyFromChannel   INT
         , @n_EmptyToChannel     INT
         , @n_UnMatchQty         INT
         , @n_QtyAvailToTransfer INT
         , @n_QtyAvailable		 INT	

         , @n_InvalidToAttr01    INT
         , @n_InvalidToAttr02    INT
         , @n_InvalidToAttr03    INT
         , @n_InvalidToAttr04    INT
         , @n_InvalidToAttr05    INT

         , @c_FromFacility       NVARCHAR(5)
         , @c_FromStorerkey      NVARCHAR(15)
         , @c_ToFacility         NVARCHAR(5)
         , @c_ToStorerkey        NVARCHAR(15)
         , @c_CustomerRefNo      NVARCHAR(20)
         , @c_ReasonCode         NVARCHAR(20)
         
         , @c_FromSku            NVARCHAR(20)
         , @c_FromChannel        NVARCHAR(10)
         , @c_FromC_Attribute01  NVARCHAR(30)
         , @c_FromC_Attribute02  NVARCHAR(30)
         , @c_FromC_Attribute03  NVARCHAR(30)
         , @c_FromC_Attribute04  NVARCHAR(30)
         , @c_FromC_Attribute05  NVARCHAR(30)
         , @n_FromQty            INT
         , @c_ToSku              NVARCHAR(20) 
         , @c_ToChannel          NVARCHAR(10)
         , @c_ToC_Attribute01    NVARCHAR(30) 
         , @c_ToC_Attribute02    NVARCHAR(30) 
         , @c_ToC_Attribute03    NVARCHAR(30) 
         , @c_ToC_Attribute04    NVARCHAR(30) 
         , @c_ToC_Attribute05    NVARCHAR(30) 
         , @n_ToQty              INT
         , @c_SourceKey          NVARCHAR(20)

         , @n_FromChannel_ID     BIGINT 
         , @n_ToChannel_ID       BIGINT 

         , @c_ChannelFromInvMgmt NVARCHAR(10)
         , @c_ChannelToInvMgmt   NVARCHAR(10)

         , @c_SQL                NVARCHAR(4000)
         , @c_SQLParms           NVARCHAR(4000)
         
   --NJOW01      
   DECLARE @c_Option1                     NVARCHAR(50)  
         , @c_Option2                     NVARCHAR(50) 
         , @c_Option3                     NVARCHAR(50) 
         , @c_Option4                     NVARCHAR(50) 
         , @c_Option5                     NVARCHAR(4000) 
         , @c_ChannelTransferAllowFNZ0Qty NVARCHAR(30) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_FromFacility   = ''
   SET @c_FromStorerkey  = ''
   SET @c_ToFacility     = ''
   SET @c_ToStorerkey    = ''
   SET @c_CustomerRefNo  = ''
   SET @c_ReasonCode     = ''

   SET @c_ChannelTransferLineNumber = ISNULL(RTRIM(@c_ChannelTransferLineNumber),'')

   SELECT  @c_FromFacility   = Facility
         , @c_FromStorerkey  = FromStorerkey
         , @c_ToFacility     = ToFacility
         , @c_ToStorerkey    = ToStorerkey
         , @c_CustomerRefNo  = ISNULL(RTRIM(CustomerRefNo),'')
         , @c_ReasonCode     = ISNULL(RTRIM(ReasonCode),'')
   FROM CHANNELTRANSFER WITH (NOLOCK)
   WHERE ChannelTransferKey = @c_ChannelTransferKey

   --WL01 S
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE @c_ChannelTRFValidationRules  NVARCHAR(100)

      SELECT @c_ChannelTRFValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_FromStorerkey
      AND SC.Configkey = 'ChannelTRFExtendedValidation'

      IF ISNULL(@c_ChannelTRFValidationRules,'') <> ''
      BEGIN
         EXEC isp_ChannelTRF_ExtendedValidation 
               @c_ChannelTransferKey = @c_ChannelTransferKey,
               @c_ChannelTRFValidationRules = @c_ChannelTRFValidationRules,
               @b_Success  = @b_Success   OUTPUT, 
               @c_ErrorMsg = @c_ErrMsg    OUTPUT,
               @c_ChannelTransferLineNumber = @c_ChannelTransferLineNumber

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62000
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SELECT @c_ChannelTRFValidationRules = SC.sValue
         FROM STORERCONFIG SC (NOLOCK)
         WHERE SC.StorerKey = @c_FromStorerkey
         AND SC.Configkey = 'ChannelTRFExtendedValidation'

         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_ChannelTRFValidationRules) AND type = 'P')
         BEGIN
            SET @c_SQL = 'EXEC ' + @c_ChannelTRFValidationRules + ' @c_ChannelTransferKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
                       + ',@c_ChannelTransferLineNumber'

            EXEC sp_EXECUTEsql @c_SQL,
                  N'@c_ChannelTransferKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT
                   ,@c_ChannelTransferLineNumber NVARCHAR(5)' ,
                  @c_ChannelTransferKey,
                  @b_Success OUTPUT,
                  @n_Err OUTPUT,
                  @c_ErrMsg OUTPUT,
                  @c_ChannelTransferLineNumber

            IF @b_Success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err = 62005
               GOTO QUIT_SP
            END
         END
      END
   END
   --WL01 E

   SET @c_ChannelFromInvMgmt = '0'
   SET @b_success = 0
       
   Execute nspGetRight2       --(Wan01) 
      @c_Facility  = @c_FromFacility
   ,  @c_StorerKey = @c_FromStorerKey        -- Storer
   ,  @c_sku       =''                      -- Sku
   ,  @c_ConfigKey = 'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_Success   = @b_success             OUTPUT
   ,  @c_authority = @c_ChannelFromInvMgmt  OUTPUT
   ,  @n_err       = @n_err                 OUTPUT
   ,  @c_errmsg    = @c_ErrMsg              OUTPUT
   ,  @c_Option1   = @c_Option1             OUTPUT --NJOW01
   ,  @c_Option2   = @c_Option2             OUTPUT 
   ,  @c_Option3   = @c_Option3             OUTPUT 
   ,  @c_Option4   = @c_Option4             OUTPUT 
   ,  @c_Option5   = @c_Option5             OUTPUT 
        
   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight'
                    + '. (isp_FinalizeChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      GOTO QUIT_SP
   END
   
   SELECT @c_ChannelTransferAllowFNZ0Qty = dbo.fnc_GetParamValueFromString('@c_ChannelTransferAllowFNZ0Qty', @c_Option5, 'N') --NJOW01

   SET @c_ChannelToInvMgmt = '0'
   SET @b_success = 0
   
   Execute nspGetRight2       --(Wan01) 
      @c_Facility  = @c_ToFacility
   ,  @c_StorerKey = @c_ToStorerKey        -- Storer
   ,  @c_sku       =''                      -- Sku
   ,  @c_ConfigKey = 'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_Success   = @b_success             OUTPUT
   ,  @c_authority = @c_ChannelToInvMgmt    OUTPUT
   ,  @n_err       = @n_err                 OUTPUT
   ,  @c_errmsg    = @c_ErrMsg              OUTPUT
   
   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62020
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight'
                    + '. (isp_FinalizeChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      GOTO QUIT_SP
   END

   IF @c_ChannelFromInvMgmt = '0' AND @c_ChannelToInvMgmt = '0'
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62030
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Both From/To Facility & Storerkey does not setup Channel Inventory.'
                    + '. (isp_FinalizeChannelTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')

      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_ReasonCode),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62040
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Reason Code is required'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END 

   SET @c_SQL = N'SELECT '
              + '  @n_EmptyFromChannel = ISNULL(SUM(CASE WHEN CTD.FromChannel = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_EmptyToChannel   = ISNULL(SUM(CASE WHEN CTD.ToChannel = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_UnMatchQty = ISNULL(SUM(CASE WHEN ISNULL(CTD.FromQty,0) = ISNULL(CTD.ToQty,0) THEN 0 ELSE 1 END),0)'
              + ' FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)'
              + ' WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey'
              + CASE WHEN @c_ChannelTransferLineNumber = '' 
                     THEN ''
                     ELSE ' AND CTD.ChannelTransferLineNumber = @c_ChannelTransferLineNumber'
                     END
              + ' AND CTD.Status < ''9'''

   SET @c_SQLParms= N'@n_EmptyFromChannel    INT   OUTPUT'
                  + ',@n_EmptyToChannel      INT   OUTPUT'
                  + ',@n_UnMatchQty          INT   OUTPUT'
                  + ',@c_ChannelTransferKey        NVARCHAR(10)'
                  + ',@c_ChannelTransferLineNumber NVARCHAR(10)'

   SET @n_EmptyFromChannel = 0
   SET @n_EmptyToChannel = 0
   SET @n_UnMatchQty     = 0
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @n_EmptyFromChannel   OUTPUT
                     , @n_EmptyToChannel     OUTPUT
                     , @n_UnMatchQty         OUTPUT
                     , @c_ChannelTransferKey
                     , @c_ChannelTransferLineNumber
         
   IF @n_EmptyFromChannel > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62050
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Found Empty From Channel'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END
         
   IF @n_EmptyToChannel > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62060
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Found Empty To Channel'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_UnMatchQty > 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62070
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Qty <> To Qty'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END
   
   SET @c_SQL = N'SELECT '
              + '  @n_EmptyFromChannel = ISNULL(SUM(CASE WHEN CINV.Channel_ID IS NULL THEN 1 ELSE 0 END),0)'
              + ', @n_QtyAvailToTransfer = ISNULL(ISNULL(CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold,0)- SUM(CTD.FromQty),0)'
              + ' FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)'
              + ' LEFT JOIN CHANNELINV CINV WITH (NOLOCK)'
                                       +  ' ON CINV.Facility = @c_FromFacility'
                                       +  ' AND CINV.Storerkey = CTD.FromStorerkey'
                                       +  ' AND CINV.Sku = CTD.FromSku'
                                       +  ' AND CINV.Channel = CTD.FromCHannel'
                                       +  ' AND CINV.C_Attribute01 = CTD.FromC_Attribute01'
                                       +  ' AND CINV.C_Attribute02 = CTD.FromC_Attribute02'
                                       +  ' AND CINV.C_Attribute03 = CTD.FromC_Attribute03'
                                       +  ' AND CINV.C_Attribute04 = CTD.FromC_Attribute04'
                                       +  ' AND CINV.C_Attribute05 = CTD.FromC_Attribute05'
              + ' WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey'
              + CASE WHEN @c_ChannelTransferLineNumber = '' 
                     THEN ''
                     ELSE ' AND CTD.ChannelTransferLineNumber = @c_ChannelTransferLineNumber'
                     END
              + ' AND CTD.Status < ''9'''
              + CASE WHEN @c_ChannelTransferAllowFNZ0Qty = 'Y' THEN
                 ' AND (CTD.FromQty > 0 OR CTD.ToQty > 0) ' ELSE ' ' END --NJOW01  
              + ' GROUP BY  CTD.FromStorerkey'
              +         ' , CTD.FromSku'
              +         ' , CTD.FromC_Attribute01'
              +         ' , CTD.FromC_Attribute02'
              +         ' , CTD.FromC_Attribute03'
              +         ' , CTD.FromC_Attribute04'
              +         ' , CTD.FromC_Attribute05'
              +         ' , ISNULL(CINV.Channel_ID,0)'
              +         ' , ISNULL(CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold,0)'
   
   SET @n_EmptyFromChannel = 0
   SET @n_QtyAvailToTransfer = 0
   SET @c_SQLParms= N'@n_EmptyFromChannel    INT   OUTPUT'
                  + ',@n_QtyAvailToTransfer  INT   OUTPUT'
                  + ',@c_ChannelTransferKey        NVARCHAR(10)'
                  + ',@c_ChannelTransferLineNumber NVARCHAR(10)'
                  + ',@c_FromFacility              NVARCHAR(5)'
   
   
   SET @n_Count = 0
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @n_EmptyFromChannel   OUTPUT
                     , @n_QtyAvailToTransfer OUTPUT
                     , @c_ChannelTransferKey
                     , @c_ChannelTransferLineNumber
                     , @c_FromFacility
   
   IF @n_EmptyFromChannel > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62080
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': From Channel Inventory Not Found.'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END
   
   IF @n_QtyAvailToTransfer < 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62090
      --SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': FromQty < Channel Available Qty Found.'  -- ZG01
      --                + '. (isp_FinalizeChannelTransfer)' 
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': FromQty > Channel Available Qty Found.'    -- ZG01
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   SET @c_SQL = N'SELECT'
              + '  @n_InvalidToAttr01 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute01 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel01),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr02 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute02 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel02),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr03 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute03 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel03),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr04 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute04 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel04),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr05 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute05 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel05),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ' FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)'
              + ' JOIN CHANNELATTRIBUTECONFIG CFG WITH (NOLOCK) ON (CTD.FromStorerkey = CFG.Storerkey)'
              + ' WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey'
              + CASE WHEN @c_ChannelTransferLineNumber = '' 
                     THEN ''
                     ELSE ' AND CTD.ChannelTransferLineNumber = @c_ChannelTransferLineNumber'
                     END
              + ' AND CTD.Status < ''9'''

   SET @c_SQLParms= N'@n_InvalidToAttr01    INT   OUTPUT'
                  + ',@n_InvalidToAttr02    INT   OUTPUT'
                  + ',@n_InvalidToAttr03    INT   OUTPUT'
                  + ',@n_InvalidToAttr04    INT   OUTPUT'
                  + ',@n_InvalidToAttr05    INT   OUTPUT'
                  + ',@c_ChannelTransferKey        NVARCHAR(10)'
                  + ',@c_ChannelTransferLineNumber NVARCHAR(10)'

   SET @n_InvalidToAttr01 = 0
   SET @n_InvalidToAttr02 = 0
   SET @n_InvalidToAttr03 = 0
   SET @n_InvalidToAttr04 = 0
   SET @n_InvalidToAttr05 = 0
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @n_InvalidToAttr01 OUTPUT
                     , @n_InvalidToAttr02 OUTPUT
                     , @n_InvalidToAttr03 OUTPUT
                     , @n_InvalidToAttr04 OUTPUT
                     , @n_InvalidToAttr05 OUTPUT
                     , @c_ChannelTransferKey
                     , @c_ChannelTransferLineNumber


   IF @n_InvalidToAttr01 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62100
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid From Channel Attribute 01. Attribute 01 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr02 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62110
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid From Channel Attribute 02. Attribute 02 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr03 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62120
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid From Channel Attribute 03. Attribute 03 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr04 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62130
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid From Channel Attribute 04. Attribute 04 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr05 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62140
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid From Channel Attribute 05. Attribute 05 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END


   SET @c_SQL = N'SELECT'
              + '  @n_InvalidToAttr01 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute01 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel01),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr02 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute02 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel02),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr03 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute03 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel03),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr04 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute04 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel04),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ', @n_InvalidToAttr05 = ISNULL(SUM(CASE WHEN CTD.ToC_Attribute05 <> '''' AND ISNULL(RTRIM(CFG.C_AttributeLabel05),'''') = '''' THEN 1 ELSE 0 END),0)'
              + ' FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)'
              + ' JOIN CHANNELATTRIBUTECONFIG CFG WITH (NOLOCK) ON (CTD.ToStorerkey = CFG.Storerkey)'
              + ' WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey'
              + CASE WHEN @c_ChannelTransferLineNumber = '' 
                     THEN ''
                     ELSE ' AND CTD.ChannelTransferLineNumber = @c_ChannelTransferLineNumber'
                     END
              + ' AND CTD.Status < ''9'''

   SET @c_SQLParms= N'@n_InvalidToAttr01    INT   OUTPUT'
                  + ',@n_InvalidToAttr02    INT   OUTPUT'
                  + ',@n_InvalidToAttr03    INT   OUTPUT'
                  + ',@n_InvalidToAttr04    INT   OUTPUT'
                  + ',@n_InvalidToAttr05    INT   OUTPUT'
                  + ',@c_ChannelTransferKey        NVARCHAR(10)'
                  + ',@c_ChannelTransferLineNumber NVARCHAR(10)'

   SET @n_InvalidToAttr01 = 0
   SET @n_InvalidToAttr02 = 0
   SET @n_InvalidToAttr03 = 0
   SET @n_InvalidToAttr04 = 0
   SET @n_InvalidToAttr05 = 0
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @n_InvalidToAttr01 OUTPUT
                     , @n_InvalidToAttr02 OUTPUT
                     , @n_InvalidToAttr03 OUTPUT
                     , @n_InvalidToAttr04 OUTPUT
                     , @n_InvalidToAttr05 OUTPUT
                     , @c_ChannelTransferKey
                     , @c_ChannelTransferLineNumber


   IF @n_InvalidToAttr01 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62150
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid To Channel Attribute 01. Attribute 01 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr02 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62160
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid To Channel Attribute 02. Attribute 02 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr03 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62170
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid To Channel Attribute 03. Attribute 03 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr04 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62180
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid To Channel Attribute 04. Attribute 04 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   IF @n_InvalidToAttr05 > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62190
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid To Channel Attribute 05. Attribute 05 Label Not Setup'
                      + '. (isp_FinalizeChannelTransfer)' 
      GOTO QUIT_SP
   END

   SET @c_SQL = N'DECLARE CUR_TRF CURSOR FAST_FORWARD READ_ONLY FOR'
              + ' SELECT ChannelTransferLineNumber = CTD.ChannelTransferLineNumber'
              + ',FromStorerkey = CTD.FromStorerkey'
              + ', FromSku = CTD.FromSku'
              + ', FromChannel = CTD.FromChannel'
              + ', FromC_Attribute01 = CTD.FromC_Attribute01'
              + ', FromC_Attribute02 = CTD.FromC_Attribute02'
              + ', FromC_Attribute03 = CTD.FromC_Attribute03'
              + ', FromC_Attribute04 = CTD.FromC_Attribute04'
              + ', FromC_Attribute05 = CTD.FromC_Attribute05'
              + ', FromQty = CTD.FromQty'
              + ', ToStorerkey = CTD.ToStorerkey'
              + ', ToSku = CTD.ToSku'
              + ', ToChannel = CTD.ToChannel'
              + ', ToC_Attribute01 = CTD.ToC_Attribute01'
              + ', ToC_Attribute02 = CTD.ToC_Attribute02'
              + ', ToC_Attribute03 = CTD.ToC_Attribute03'
              + ', ToC_Attribute04 = CTD.ToC_Attribute04'
              + ', ToC_Attribute05 = CTD.ToC_Attribute05'
              + ', ToQty = CTD.ToQty'
              + ' FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)'
              + ' WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey'
              + CASE WHEN @c_ChannelTransferLineNumber = '' 
                     THEN ''
                     ELSE ' AND CTD.ChannelTransferLineNumber = @c_ChannelTransferLineNumber'
                     END
              + ' AND CTD.Status < ''9'''

   SET @c_SQLParms= N'@c_ChannelTransferKey        NVARCHAR(10)'
                  + ',@c_ChannelTransferLineNumber NVARCHAR(10)'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_ChannelTransferKey
                     , @c_ChannelTransferLineNumber

   OPEN CUR_TRF
   
   FETCH NEXT FROM CUR_TRF INTO @c_ChannelTransferLineNumber
                              , @c_FromStorerkey
                              , @c_FromSku
                              , @c_FromChannel
                              , @c_FromC_Attribute01
                              , @c_FromC_Attribute02
                              , @c_FromC_Attribute03
                              , @c_FromC_Attribute04
                              , @c_FromC_Attribute05  
                              , @n_FromQty
                              , @c_ToStorerkey
                              , @c_ToSku
                              , @c_ToChannel
                              , @c_ToC_Attribute01
                              , @c_ToC_Attribute02
                              , @c_ToC_Attribute03
                              , @c_ToC_Attribute04
                              , @c_ToC_Attribute05
                              , @n_ToQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	  IF @c_ChannelTransferAllowFNZ0Qty = 'Y' AND (@n_FromQty = 0 OR @n_ToQty = 0)  --NJOW01
   	  BEGIN
         UPDATE CHANNELTRANSFERDETAIL WITH (ROWLOCK)
         SET Status = '9'
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()
         WHERE ChannelTransferKey = @c_ChannelTransferKey
         AND   ChannelTransferLineNumber = @c_ChannelTransferLineNumber
            	  	
   	     GOTO NEXT_TRFREC
   	  END
   	
      SET @n_FromChannel_ID = 0 
      SELECT @n_FromChannel_ID = ci.Channel_ID 
			,@n_QtyAvailable = CI.Qty - CI.QtyAllocated - CI.QtyOnHold
      FROM CHANNELINV AS ci WITH(NOLOCK)
      WHERE ci.StorerKey = @c_FromStorerKey 
      AND   ci.SKU = @c_FromSku
      AND   ci.Facility = @c_FromFacility 
      AND   ci.Channel  = @c_FromChannel 
      AND   ci.C_Attribute01 = @c_FromC_Attribute01
      AND   ci.C_Attribute02 = @c_FromC_Attribute02
      AND   ci.C_Attribute03 = @c_FromC_Attribute03
      AND   ci.C_Attribute04 = @c_FromC_Attribute04
      AND   ci.C_Attribute05 = @c_FromC_Attribute05

      IF @n_QtyAvailable < @n_FromQty
      BEGIN
	      SET @n_Continue = 3
	      SET @n_Err      = 62200
	      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Channel Available Qty is less than Qty To Transfer'
					      + '. (isp_FinalizeChannelTransfer)' 
	      GOTO QUIT_SP
      END

      SET @c_SourceKey = RTRIM(@c_ChannelTransferKey)  
                       + RTRIM(@c_ChannelTransferLineNumber)

      SET @n_ToChannel_ID = 0
      EXEC  isp_FinalizeChannelInvTransfer
            @c_Facility       = @c_FromFacility
         ,  @c_Storerkey      = @c_FromStorerkey
         ,  @n_Channel_id     = @n_FromChannel_ID
         ,  @c_ToChannel      = @c_ToChannel
         ,  @n_ToQty          = @n_ToQty
         ,  @n_ToQtyOnHold    = 0
         ,  @c_CustomerRef    = @c_CustomerRefNo
         ,  @c_Reasoncode     = @c_Reasoncode
         ,  @b_Success        = @b_Success         OUTPUT
         ,  @n_Err            = @n_Err             OUTPUT
         ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT 
         ,  @c_SourceKey      = @c_Sourcekey
         ,  @c_SourceType     = 'isp_FinalizeChannelTransfer'
         ,  @c_ToFacility     = @c_ToFacility
         ,  @c_ToStorerkey    = @c_ToStorerkey
         ,  @c_ToSku          = @c_ToSku
         ,  @c_ToC_Attribute01= @c_ToC_Attribute01 
         ,  @c_ToC_Attribute02= @c_ToC_Attribute02  
         ,  @c_ToC_Attribute03= @c_ToC_Attribute03  
         ,  @c_ToC_Attribute04= @c_ToC_Attribute04  
         ,  @c_ToC_Attribute05= @c_ToC_Attribute05  
         ,  @n_ToChannel_ID   = @n_ToChannel_ID    OUTPUT 

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 62150
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Executing isp_FinalizeChannelInvTransfer'
                         + '. (isp_FinalizeChannelTransfer)' 
         GOTO QUIT_SP
      END      

      IF @n_ToChannel_ID > 0  
      BEGIN
         UPDATE CHANNELTRANSFERDETAIL WITH (ROWLOCK)
         SET Status = '9'
            ,FromChannel_ID = @n_FromChannel_ID
            ,ToChannel_ID   = @n_ToChannel_ID
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()
         WHERE ChannelTransferKey = @c_ChannelTransferKey
         AND   ChannelTransferLineNumber = @c_ChannelTransferLineNumber

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) 
            SET @n_Err      = 62160
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update CHANNELTRANSFERDETAIL Fail'
                            + '. (isp_FinalizeChannelTransfer)( SQLSvr MESSAGE='
                            + RTRIM(@c_Errmsg) + ' ) '
            GOTO QUIT_SP
         END
      END 
      
      NEXT_TRFREC:

      FETCH NEXT FROM CUR_TRF INTO @c_ChannelTransferLineNumber
                                 , @c_FromStorerkey
                                 , @c_FromSku
                                 , @c_FromChannel
                                 , @c_FromC_Attribute01
                                 , @c_FromC_Attribute02
                                 , @c_FromC_Attribute03
                                 , @c_FromC_Attribute04
                                 , @c_FromC_Attribute05  
                                 , @n_FromQty
                                 , @c_ToStorerkey
                                 , @c_ToSku
                                 , @c_ToChannel
                                 , @c_ToC_Attribute01
                                 , @c_ToC_Attribute02
                                 , @c_ToC_Attribute03
                                 , @c_ToC_Attribute04
                                 , @c_ToC_Attribute05
                                 , @n_ToQty
   END
   CLOSE CUR_TRF
   DEALLOCATE CUR_TRF 

   IF NOT EXISTS (SELECT 1
                  FROM CHANNELTRANSFERDETAIL CTD WITH (NOLOCK)
                  WHERE CTD.ChannelTransferKey = @c_ChannelTransferKey
                  AND   CTD.Status < '9'
                  )
   BEGIN
      UPDATE CHANNELTRANSFER WITH (ROWLOCK)
      SET Status = '9'
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
      WHERE ChannelTransferKey = @c_ChannelTransferKey

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) 
         SET @n_Err      = 62170
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update CHANNELTRANFER Fail'
                           + '. (isp_FinalizeChannelTransfer)( SQLSvr MESSAGE='
                           + RTRIM(@c_Errmsg) + ' ) '
         GOTO QUIT_SP
      END         
   END
QUIT_SP:
   IF CURSOR_STATUS( 'GLOBAL', 'CUR_TRF') in (0 , 1)  
   BEGIN
      CLOSE CUR_TRF
      DEALLOCATE CUR_TRF
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_FinalizeChannelTransfer'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO