SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFIDTagReadChk01                                    */
/* Creation Date: 2021-01-11                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR              */
/*        :                                                             */
/* Called By: Of_RFIDValidateTag                                        */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-01-11  Wan      1.0   Created                                   */
/* 2021-02-19  Wan01    1.1   Fixed.                                    */
/* 2022-11-11  Wan02    1.2   WMS-21150 - [CN] Nike Ecom Packing        */
/*                            Chinesization                             */
/* 2022-11-11  Wan02    1.2   DevOps Combine Script                     */
/* 2023-01-05  Wan03    1.3   WMS-21467-[CN]NIKE_Ecom_NFC RFID Receiving-CR*/
/************************************************************************/
CREATE   PROC isp_RFIDTagReadChk01
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
         
         , @c_SkuGroup           NVARCHAR(10) = ''             
         , @c_TagReader          NVARCHAR(10) = ''             -- (Wan03)
         , @c_ListName_TagReader NVARCHAR(10) = ''             -- (Wan03)
         
         , @c_TryLimit           NVARCHAR(10) = ''
         , @c_RFIDTagReadChk_SP  NVARCHAR(30) = '' 
         
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
      SET @n_err = 89010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                   + ': '
                   + dbo.fnc_GetLangMsgText(                 --(Wan02)
                     'sp_Exec_Err'               
                   , 'Error Executing nspGetRight.'
                   , 'nspGetRight')
                   +' (isp_RFIDTagReadChk01)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END
      
   SET @c_TryLimit = CASE WHEN ISNUMERIC(@c_TryLimit) = 1 THEN @c_TryLimit ELSE 5 END
      
   IF @c_TryLimit = 0 SET @c_TryLimit = '5'    

   INSERT INTO @TRFID ( SeqNo )
   SELECT S.VALUE
   FROM string_split (@c_SeqNos, '|') S
   
   SELECT TOP 1 @n_NoOfTag_Read = S.SeqNo             --(Wan03)
   FROM @TRFID S
   WHERE S.SeqNo > 0
   ORDER BY S.SeqNo DESC                              --(Wan03)

   SELECT @n_NoOfTag_SKU = CASE WHEN ISNUMERIC(s.SUSR1) = 1 THEN s.SUSR1 ELSE 0 END
         ,@c_SkuGroup = ISNULL(s.SKUGROUP,'')
         ,@c_TagReader = RTRIM(si.ExtendedField03)    --(Wan03)
   FROM SKU AS s WITH (NOLOCK)
   JOIN SKUINFO AS si WITH (NOLOCK) ON  si.StorerKey = s.StorerKey
                                    AND si.Sku = s.Sku
   WHERE s.Storerkey = @c_Storerkey                   --(Wan01) Fixed
   AND s.Sku = @c_Sku
   AND si.ExtendedField03 IN ('NFC', 'RFID')          --(Wan03)

   IF @c_SkuGroup <> '' 
   BEGIN
      SET @c_ListName_TagReader = CASE @c_TagReader WHEN 'nfc' THEN 'NFCTag'              --(Wan03)
                                                    ELSE 'RFIDTag'
                                                    END
      SELECT @n_NoOfTag_SKU = @n_NoOfTag_SKU + CASE WHEN ISNUMERIC(c.Short) = 1 THEN c.Short ELSE 0 END
      FROM CODELKUP AS c WITH (NOLOCK)
      WHERE c.LISTNAME = @c_ListName_TagReader                                            --(Wan03)
      AND   c.Storerkey= @c_Storerkey
      AND   c.Code = @c_SkuGroup
   END

   IF @n_NoOfTag_SKU = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 89020
      SET @c_ErrMsg   = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                      + ': '
                      + dbo.fnc_GetLangMsgText(                                        --(Wan02)
                        'sp_RFID_READ_ItemTagNoSet'               
                      , 'No Of %s Tag Per Sku Not Setup.'                              --(Wan03)
                      , @c_TagReader)                                                  --(Wan03)  
                      + ' (isp_RFIDTagReadChk01)'  

      GOTO QUIT_SP
   END
   
   IF @n_NoOfTag_SKU > @n_NoOfTag_Read
   BEGIN
      IF @n_Try >= CONVERT(INT,@c_TryLimit)
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 81030   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                      + ': '
                      + dbo.fnc_GetLangMsgText(                 --(Wan02)
                        'sp_RFID_READ_FailGetTags'               
                      , 'Unable to get complete %s Tag Value after try limit. Please check.'      --(Wan03)
                      , @c_TagReader)                                                             --(Wan03)
                      + ' (isp_RFIDTagReadChk01)'  
         GOTO QUIT_SP  
      END
      
      SET @n_Try = @n_Try + 1
      SET @b_Success = 2  
      GOTO QUIT_SP   
   END
   
   IF @n_NoOfTag_SKU < @n_NoOfTag_Read                         --(Wan03) - START
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81040   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     + ': '
                     + dbo.fnc_GetLangMsgText(                 
                     'sp_RFID_READ_GetMoreTags'               
                     , 'More %s tag detected. Please check.'   
                     , @c_TagReader)                                                            
                     + ' (isp_RFIDTagReadChk01)'  
      GOTO QUIT_SP  
   END                                                         --(Wan03) - END
   
   SET @b_Success = 1
   
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