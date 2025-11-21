SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFIDTagReadCheck_Wrapper                            */
/* Creation Date: 2021-01-11                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR              */
/*        :                                                             */
/* Called By: Of_RFIDValidateTag                                        */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-01-11  Wan      1.0   Created                                   */
/* 2022-11-11  Wan01    1.1   WMS-21150 - [CN] Nike Ecom Packing        */
/*                            Chinesization                             */
/* 2022-11-11  Wan01    1.1   DevOps Combine Script                     */
/* 2022-03-01  Wan02    1.2   WMS-21512 - [CN] NIKE_NFC_RFID_ECOMPACKING*/
/*                            _CR_V1.0                                  */
/************************************************************************/
CREATE   PROC isp_RFIDTagReadCheck_Wrapper
           @n_Try          INT               OUTPUT
         , @c_Facility     NVARCHAR(5)
         , @c_Storerkey    NVARCHAR(10)
         , @c_Sku          NVARCHAR(20)
         , @c_SeqNos       NVARCHAR(1000)= ''   --Multiple RFIDTagSeqNo seperate by '|'          
         , @c_TidNos       NVARCHAR(1000)= ''   --Multiple TIDNo  seperate by '|'
         , @c_RFIDNos      NVARCHAR(1000)= ''   --Multiple RFIDNo seperate by '|'           
         , @b_Success      INT          = 1  OUTPUT --@b_Success = 0:Error, 1: Complete Reading, 2:Imcomplete Reading
         , @n_Err          INT          = 0  OUTPUT
         , @c_ErrMsg       NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT = @@TRANCOUNT
         , @n_Continue           INT = 1

         , @n_NoOfTag_Read       INT = 0
         , @n_NoOfTag_SKU        INT = 0
         
         , @c_TryLimit           NVARCHAR(10) = ''
         , @c_RFIDTagReadChk_SP  NVARCHAR(30) = ''
         , @c_SQL                NVARCHAR(4000) =''
         , @c_SQLParms           NVARCHAR(4000) =''
         
         , @c_TagReader          NVARCHAR(10) = '' --(Wan02)
         
   DECLARE @TRFID TABLE 
         ( RowRef             INT      NOT NULL IDENTITY(1,1) PRIMARY KEY
         , SeqNo              INT           NOT NULL DEFAULT(0)
         , TIDNo              NVARCHAR(100) NOT NULL DEFAULT('')         
         , RFIDNo             NVARCHAR(100) NOT NULL DEFAULT('')
         )
   
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_RFIDTagReadChk_SP = ''
   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'RFIDTagReadChk_SP' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_RFIDTagReadChk_SP   OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT
      ,  @c_Option1    = @c_TryLimit            OUTPUT 

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81020   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ': '
                   + dbo.fnc_GetLangMsgText(                 --(Wan01)
                     'sp_Exec_Err'               
                   , 'Error Executing nspGetRight.'
                   , 'nspGetRight')
                  +' (isp_RFIDTagReadCheck_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END
   -- Standard to Return if At least 1 Tag is return
   INSERT INTO @TRFID ( SeqNo )
   SELECT S.VALUE
   FROM string_split (@c_SeqNos, '|') S
   
   SELECT @n_NoOfTag_Read = S.SeqNo
   FROM @TRFID S
   WHERE S.SeqNo > 0
   
   IF @n_NoOfTag_Read = 0 
   BEGIN
      SET @c_TagReader = 'RFID'                             --(Wan02)
      SELECT @c_TagReader = RTRIM(si.ExtendedField03)                                   
      FROM SKUINFO AS si WITH (NOLOCK) 
      WHERE si.Storerkey = @c_Storerkey          
      AND si.Sku = @c_Sku
      AND si.ExtendedField03 IN ('NFC')
   
      SET @c_TryLimit = CASE WHEN ISNUMERIC(@c_TryLimit) = 1 THEN @c_TryLimit ELSE 5 END
      
      IF @c_TryLimit = 0 SET @c_TryLimit = '5'
      
      IF @n_Try >= CONVERT(INT,@c_TryLimit)
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 81010 
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                      + ': '
                      + dbo.fnc_GetLangMsgText(                --(Wan01)
                        'sp_RFID_ReadTag_MaxLimitTry'               
                      , 'Unable to get %s Tag Value after try limit. Please check.' --(Wan02)
                      , @c_TagReader)                                               --(Wan02)
                      +' (isp_RFIDTagReadCheck_Wrapper)' 
         GOTO QUIT_SP  
      END
      
      SET @n_Try = @n_Try + 1
      SET @b_Success = 2
      GOTO QUIT_SP
   END

   IF @c_RFIDTagReadChk_SP= '0'
   BEGIN
      SET @b_Success = 1
      GOTO QUIT_SP 
   END
   
   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDTagReadChk_SP) AND [Type] = 'P') 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81030   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                   + ': '
                   + dbo.fnc_GetLangMsgText(                 --(Wan01)
                     'sp_Invalid_SP'               
                   , 'Invalid Custom SP: ' + + @c_RFIDTagReadChk_SP + '.'
                   , @c_RFIDTagReadChk_SP)
                   +' (isp_RFIDTagReadCheck_Wrapper)'  
      GOTO QUIT_SP 
   END

   SET @b_Success = 1
   SET @c_SQL = N'EXEC ' + @c_RFIDTagReadChk_SP
               +'  @n_Try        = @n_Try     OUTPUT'   
               +', @c_Facility   = @c_Facility'    
               +', @c_Storerkey  = @c_Storerkey' 
               +', @c_Sku        = @c_Sku'      
               +', @c_SeqNos     = @c_SeqNos' 
               +', @c_TidNos     = @c_TidNos'                           
               +', @c_RFIDNos    = @c_RFIDNos'   
               +', @b_Success    = @b_Success OUTPUT'
               +', @n_Err        = @n_Err     OUTPUT'
               +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'

   SET @c_SQLParms= N'@n_Try         INT           OUTPUT'   
                  +', @c_Facility    NVARCHAR(5)'   
                  +', @c_Storerkey   NVARCHAR(15)'
                  +', @c_Sku         NVARCHAR(20)'
                  +', @c_SeqNos      NVARCHAR(1000)'  
                  +', @c_TidNos      NVARCHAR(1000)'                             
                  +', @c_RFIDNos     NVARCHAR(1000)'   
                  +', @b_Success     INT           OUTPUT'
                  +', @n_Err         INT           OUTPUT'
                  +', @c_ErrMsg      NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @n_Try         OUTPUT
                     , @c_Facility     
                     , @c_Storerkey   
                     , @c_Sku          
                     , @c_SeqNos    
                     , @c_TidNos  
                     , @c_RFIDNos                  
                     , @b_Success      OUTPUT
                     , @n_Err          OUTPUT
                     , @c_ErrMsg       OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81040   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                   + ': '
                   + dbo.fnc_GetLangMsgText(                 --(Wan01)
                     'sp_Exec_Err'               
                   , 'Error Executing ' + + @c_RFIDTagReadChk_SP + '.'
                   , @c_RFIDTagReadChk_SP)
                   +' (isp_RFIDTagReadCheck_Wrapper)' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END
 
   QUIT_SP:
   
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
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO