SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNValidateRFIDNo                              */
/* Creation Date: 2020-08-28                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-OCT-2020 Wan      1.0   Created                                   */
/* 03-MAR-2021 Wan01    1.1   WMS-16467 - [CN]NIKE_O2_RFID_Receiving_ChangeField_CR*/
/* 08-APR-2021 Wan02    1.2   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                */
/* 14-NOV-2022 NJOW01   1.3   Change storerkey filter to EXTERNORDERS   */
/*                            to take advantage of current index        */
/* 14-NOV-2022 NJOW01   1.3   DEVOPS Combine Script                     */
/* 05-JAN-2023 Wan03    1.4   WMS-21467-[CN]NIKE_Ecom_NFC RFID Receiving-CR*/
/* 10-AUG-2023 PakYuen  1.5   JSM-167988 - Tune performance (PY01)      */ 
/* 19-SEP-2023 Wan04    1.6   WMS-23643 - [CN]NIKE_B2C_Creturn_NFC_     */
/*                            Ehancement_Function CR                    */
/* 29-SEP-2023 Wan05    1.7   Tune performance issue for JSM-167988     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RFID_ASNValidateRFIDNo]
           @c_ReceiptKey         NVARCHAR(10)
         , @c_RFIDNo1            NVARCHAR(100)= ''  
         , @c_TidNo1             NVARCHAR(100)= '' 
         , @c_RFIDNo2            NVARCHAR(100)= '' 
         , @c_TidNo2             NVARCHAR(100)= '' 
         , @c_Sku                NVARCHAR(20) = '' --OUTPUT --(Wan03) PB define as input Parameter
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1

         , @n_MatchTidNo1     INT = 0
         , @n_MatchTidNo2     INT = 0

         , @c_Facility        NVARCHAR(5)  = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_CarrierName     NVARCHAR(45) = ''    --Wan01

         , @c_Sku1            NVARCHAR(20) = ''
         , @c_Sku2            NVARCHAR(20) = ''

         , @c_RFIDValidateSku_SP NVARCHAR(30)   = ''

         , @c_SQL                NVARCHAR(MAX)  = ''
         , @c_SQLParms           NVARCHAR(MAX)  = ''
         
         , @c_TagReader          NVARCHAR(10)   = '' --(Wan03)
         
         , @n_DiffSkuCnt         INT            = 0                                 --(Wan04)   
         , @n_ASNSameSkuCnt      INT            = 0                                 --(Wan04)  
         
   DECLARE @t_CheckNFC           TABLE
         ( RowId                 INT            IDENTITY(1,1)  PRIMARY KEY
         , NFC                   NVARCHAR(50)   DEFAULT('')
         , Storerkey             NVARCHAR(15)   DEFAULT('')
         , Sku                   NVARCHAR(20)   DEFAULT('')
         , Receiptkey            NVARCHAR(10)   DEFAULT('')                         --(Wan04)
         )

   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_Sku = ISNULL(@c_Sku, '')           --2021-01-07
   
   SELECT   @c_Facility     = RH.Facility
         ,  @c_Storerkey    = RH.Storerkey
         ,  @c_CarrierName = ISNULL(RH.CarrierName,'')   --(Wan01)
   FROM RECEIPT RH WITH (NOLOCK)
   WHERE RH.ReceiptKey = @c_ReceiptKey
  
   SET @c_TagReader = 'RFID'                             --(Wan03)
   SELECT @c_TagReader = RTRIM(si.ExtendedField03)                                   
   FROM SKUINFO AS si WITH (NOLOCK) 
   WHERE si.Storerkey = @c_Storerkey          
   AND si.Sku = @c_Sku
   AND si.ExtendedField03 IN ('NFC')
   
   --SELECT @c_Sku1 = MAX(CASE WHEN EOD.RFIDNo = @c_RFIDNo1 THEN EOD.Sku ELSE '' END               --Wan05 - START
   --   ,   @c_Sku2 = MAX(CASE WHEN EOD.RFIDNo = @c_RFIDNo2 THEN EOD.Sku ELSE '' END)
   --   ,   @n_MatchTidNo1 = MAX(CASE WHEN EOD.RFIDNo = @c_RFIDNo1 AND EOD.TidNo = @c_TidNo1 THEN 1 ELSE 0 END)
   --   ,   @n_MatchTidNo2 = MAX(CASE WHEN EOD.RFIDNo = @c_RFIDNo2 AND EOD.TidNo = @c_TidNo2 THEN 1 ELSE 0 END)
   --FROM EXTERNORDERS EOH WITH (NOLOCK) 
   --JOIN EXTERNORDERSDETAIL EOD WITH (NOLOCK) ON EOH.ExternOrderKey = EOD.ExternOrderKey
   --WHERE EOD.RFIDNo IN ( @c_RFIDNo1, @c_RFIDNo2 )
   --AND   EOD.RFIDNo <> ''                                 --PY01
   --AND   EOH.Storerkey = @c_Storerkey
   --AND   EOH.PlatFormorderNo = @c_CarrierName                   --Wan02--(Wan01)
   --AND   EOH.[Status]  = '9'
   --GROUP BY EOH.Storerkey
   --      ,  EOH.Externorderkey
   --      ,  EOH.[Status]                   

   SELECT TOP 1 
          @c_Sku1 = EOD.Sku
      ,   @n_MatchTidNo1 = 1
   FROM EXTERNORDERS EOH WITH (NOLOCK) 
   JOIN EXTERNORDERSDETAIL EOD WITH (NOLOCK) ON EOH.ExternOrderKey = EOD.ExternOrderKey
   WHERE EOD.RFIDNo = @c_RFIDNo1
   AND   EOD.RFIDNo <> '' 
   AND   EOD.TidNo = @c_TidNo1 
   AND   EOD.TidNo <> ''   
   AND   EOD.Storerkey = @c_Storerkey 
   AND   EOD.Sku = @c_Sku  
   AND   EOH.Storerkey = @c_Storerkey
   AND   EOH.PlatFormorderNo = @c_CarrierName                   
   AND   EOH.[Status]  = '9'
   
   IF @c_TagReader = 'RFID' 
   BEGIN
      SELECT TOP 1 
             @c_Sku2 = EOD.Sku
         ,   @n_MatchTidNo2 = 1
      FROM EXTERNORDERS EOH WITH (NOLOCK) 
      JOIN EXTERNORDERSDETAIL EOD WITH (NOLOCK) ON EOH.ExternOrderKey = EOD.ExternOrderKey
      WHERE EOD.RFIDNo = @c_RFIDNo2
      AND   EOD.RFIDNo <> '' 
      AND   EOD.TidNo = @c_TidNo2 
      AND   EOD.TidNo <> ''   
      AND   EOD.Storerkey = @c_Storerkey 
      AND   EOD.Sku = @c_Sku  
      AND   EOH.Storerkey = @c_Storerkey
      AND   EOH.PlatFormorderNo = @c_CarrierName                   
      AND   EOH.[Status]  = '9'    
   END                                                                                             --Wan05 - END

   IF @c_TagReader = 'RFID'                                                            --(Wan03) - START                         
   BEGIN         
      IF @c_Sku1 = '' AND @c_Sku2 = '' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84010
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Both Left and Right RFIDNo For Receive''s Sales Order: ' + @c_CarrierName   --(Wan01)
                         + ' not found. (isp_RFID_ASNValidateRFIDNo)'
         GOTO QUIT_SP
      END

      IF @c_Sku1 = '' OR @c_Sku2 = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84020
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Either Left or Right RFIDNo Does Not Found in Received Sales Order.'
                           + ' (isp_RFID_ASNValidateRFIDNo)'

         GOTO QUIT_SP
      END

      IF @c_Sku1 <> @c_Sku2 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84030
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Both RFIDNo''s Sku are unmatch.'
                           + ' (isp_RFID_ASNValidateRFIDNo)'
         GOTO QUIT_SP
      END
   END                                                                                 --(Wan03) - END
   
   IF @c_TagReader = 'NFC'                                                             --(Wan03) - START
   BEGIN
      IF @c_Sku1 = '' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84035
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': NFC Tag For Receive''s Sales Order: ' + @c_CarrierName   --(Wan01)
                         + ' not found. (isp_RFID_ASNValidateRFIDNo)'
         GOTO QUIT_SP
      END
      
      INSERT INTO @t_CheckNFC ( NFC, Storerkey, Sku, Receiptkey )
      SELECT @c_RFIDNo1, @c_Storerkey, @c_Sku, @c_ReceiptKey 
      UNION ALL
      SELECT di.Key1, di.Storerkey, di.Key2, di.Key3
      FROM dbo.DocInfo AS di (NOLOCK) 
      WHERE di.Tablename = 'NFCRecord'
      AND di.StorerKey = @c_Storerkey
      AND di.Key1 = @c_RFIDNo1    

      SELECT @n_DiffSkuCnt    = COUNT(DISTINCT tcn.Sku)                             --(Wan04) - START
            ,@n_ASNSameSkuCnt = SUM(CASE WHEN tcn.Sku = @c_Sku AND tcn.Receiptkey = @c_ReceiptKey  
                                         THEN 1
                                         ELSE 0 END)      
      FROM @t_CheckNFC AS tcn
      WHERE NFC = @c_RFIDNo1
      
      IF @n_DiffSkuCnt > 1 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84037
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Duplicate NFC Tag for sku found'
                         + '. (isp_RFID_ASNValidateRFIDNo)'
         GOTO QUIT_SP   
      END
      
      IF @n_ASNSameSkuCnt > 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 84038
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': NFC Tag with same sku found' 
                         + '. (isp_RFID_ASNValidateRFIDNo)'
         GOTO QUIT_SP   
      END
      --(Wan04) - END
   END                                                                                 --(Wan03) - END
   
   IF @n_MatchTidNo1 = 0 OR (@n_MatchTidNo2 = 0 AND @c_TagReader = 'RFID')             --(Wan03)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 84040
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Unmatch RFIDNo and TidNo is/are found.'
                      + ' (isp_RFID_ASNValidateRFIDNo)'
      GOTO QUIT_SP
   END

   --2021-01-07 for Scanned Sku then scanned RFID
   IF @c_Sku <> @c_Sku1 AND @c_Sku <> '' 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 84050
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Scanned Sku and ' + @c_TagReader 
                      + ' Sku are unmatch.'
                      + ' (isp_RFID_ASNValidateRFIDNo)'
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1
                  FROM RECEIPTDETAIL RD WITH (NOLOCK)
                  WHERE RD.ReceiptKey = @c_ReceiptKey
                  AND   RD.Storerkey  = @c_Storerkey
                  AND   RD.Sku        = @c_Sku1
                  AND   RD.BeforeReceivedQty = 0
                  )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 84060
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': ' + @c_TagReader
                      + ' Sku not Found in Receipt or Sku is received.'
                      + ' (isp_RFID_ASNValidateRFIDNo)'
      GOTO QUIT_SP
   END

   --SET @c_Sku = @c_Sku1              --(Wan03) Not a Output Parameter
  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNValidateRFIDNo'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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