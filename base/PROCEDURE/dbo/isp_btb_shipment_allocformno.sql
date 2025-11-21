SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_BTB_Shipment_AllocFormNo                            */
/* Creation Date: 08-NOV-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  isp_BTB_Shipment_AllocFormNo                               */
/*        :                                                             */
/* Called By: nep_n_cst_btb_shipment.ue_allocate_Formno                 */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_BTB_Shipment_AllocFormNo]
           @c_BTB_ShipmentKey NVARCHAR(10)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT
         , @n_Continue                 INT 

         , @c_BTB_ShipmentListNo       NVARCHAR(10)
         , @c_BTB_ShipmentLineNo       NVARCHAR(10)
         , @c_BTB_ShipmentLineNo_New   NVARCHAR(10)
         , @c_FormType                 NVARCHAR(5)
         , @c_FormNo                   NVARCHAR(50)
         , @c_HSCode                   NVARCHAR(20)
         , @c_Storerkey                NVARCHAR(15)
         , @c_Sku                      NVARCHAR(20)
         , @c_BTBShipItem              NVARCHAR(50)

         ,  @c_PermitNo                NVARCHAR(20)
         ,  @dt_IssuedDate             DATETIME
         ,  @c_IssueCountry            NVARCHAR(30)
         ,  @c_IssueAuthority          NVARCHAR(100)

         , @n_QtyExported              INT
         , @n_QtyBalance               INT

         , @b_NewDetailInserted        BIT
         , @b_NoMatchFormNo            BIT

         , @CUR_BTBSHPDET              CURSOR

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END

   SET @b_NoMatchFormNo = 0
   START_ALLOCATE:
   SET @b_NewDetailInserted = 0
   SET @CUR_BTBSHPDET = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT SD.BTB_ShipmentListNo
         ,SD.BTB_ShipmentLineNo 
         ,SH.FormType
         ,SD.HSCode
         ,SD.Storerkey
         ,SD.Sku
         ,SD.BTBShipItem 
         ,SD.QtyExported 
   FROM BTB_SHIPMENT       SH WITH (NOLOCK)  
   JOIN BTB_SHIPMENTDETAIL SD WITH (NOLOCK) ON (SH.BTB_ShipmentKey = SD.BTB_ShipmentKey)
   WHERE SD.BTB_ShipmentKey = @c_BTB_ShipmentKey
   AND   SD.FormNo = ''
   ORDER BY SD.BTB_ShipmentListNo
         ,  SD.BTB_ShipmentLineNo
   
   OPEN @CUR_BTBSHPDET
   
   FETCH NEXT FROM @CUR_BTBSHPDET INTO @c_BTB_ShipmentListNo
                                    ,  @c_BTB_ShipmentLineNo
                                    ,  @c_FormType
                                    ,  @c_HSCode
                                    ,  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @c_BTBShipItem 
                                    ,  @n_QtyExported 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_FormNo = ''
      SET @n_QtyBalance = 0

      SET @c_PermitNo    = ''
      SET @dt_IssuedDate = '1900-01-01'
      SET @c_IssueCountry= ''  
      SET @c_IssueAuthority = ''

      SELECT TOP 1 @c_FormNo = BTB_FTA.FormNo 
            ,  @c_PermitNo    = PermitNo
            ,  @dt_IssuedDate = IssuedDate
            ,  @c_IssueCountry= IssueCountry  
            ,  @c_IssueAuthority = IssueAuthority
            ,  @n_QtyBalance  = BTB_FTA.QtyImported - BTB_FTA.QtyExported        
      FROM BTB_FTA WITH (NOLOCK)  
      WHERE BTB_FTA.FormType = @c_FormType
	   AND BTB_FTA.HSCode = @c_HSCode
   	AND BTB_FTA.Storerkey = @c_Storerkey
	   AND BTB_FTA.Sku = @c_Sku
	   AND BTB_FTA.BTBShipItem = @c_BTBShipItem
      AND BTB_FTA.IssuedDate > DATEADD(day, -365, GETDATE())
	   AND BTB_FTA.EnabledFlag = 'Y'
	   AND BTB_FTA.QtyImported - BTB_FTA.QtyExported > 0 
      ORDER BY BTB_FTA.IssuedDate

      IF @c_FormNo = ''
      BEGIN
         SET @b_NoMatchFormNo = 1  
      END
      ELSE
      BEGIN
         BEGIN TRAN

         IF @n_QtyBalance - @n_QtyExported < 0
         BEGIN
            SET @c_BTB_ShipmentLineNo_New = ''
            SELECT @c_BTB_ShipmentLineNo_New = RIGHT('00000' + CONVERT(NVARCHAR(5),(ISNULL(MAX(BTB_ShipmentLineNo),0) + 1)),5)
            FROM BTB_SHIPMENTDETAIL WITH (NOLOCK)
            WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey
            AND   BTB_ShipmentListNo = @c_BTB_ShipmentListNo

            INSERT INTO BTB_SHIPMENTDETAIL
               (  BTB_ShipmentKey
               ,  BTB_ShipmentListNo
               ,  BTB_ShipmentLineNo
               ,  FormNo
               ,  HSCode
               ,  PermitNo
               ,  IssuedDate
               ,  Storerkey
               ,  Sku
               ,  SkuDescr      
               ,  UOM           
               ,  Price         
               ,  Currency      
               ,  QtyExported   
               ,  Wavekey       
               ,  UserDefine01  
               ,  UserDefine02  
               ,  UserDefine03  
               ,  UserDefine04  
               ,  UserDefine05  
               ,  UserDefine06  
               ,  UserDefine07  
               ,  UserDefine08  
               ,  UserDefine09  
               ,  UserDefine10  
               ,  IssueCountry  
               ,  IssueAuthority
               ,  BTBShipItem 
               )
            SELECT BTB_ShipmentKey
               ,  BTB_ShipmentListNo
               ,  @c_BTB_ShipmentLineNo_New
               ,  FormNo
               ,  HSCode
               ,  PermitNo
               ,  IssuedDate
               ,  Storerkey
               ,  Sku
               ,  SkuDescr      
               ,  UOM           
               ,  Price         
               ,  Currency      
               ,  @n_QtyExported - @n_QtyBalance   
               ,  Wavekey       
               ,  UserDefine01  
               ,  UserDefine02  
               ,  UserDefine03  
               ,  UserDefine04  
               ,  UserDefine05  
               ,  UserDefine06  
               ,  UserDefine07  
               ,  UserDefine08  
               ,  UserDefine09  
               ,  UserDefine10  
               ,  IssueCountry  
               ,  IssueAuthority
               ,  BTBShipItem 
            FROM BTB_SHIPMENTDETAIL WITH (NOLOCK)
            WHERE  BTB_ShipmentKey    = @c_BTB_ShipmentKey
            AND    BTB_ShipmentListNo = @c_BTB_ShipmentListNo
            AND    BTB_ShipmentLineNo = @c_BTB_ShipmentLineNo 

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(5),@n_err)
               SET @n_err=63510
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT Into Table BTB_SHIPMENTDETAIL fail. (isp_BTB_Shipment_AllocFormNo)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_SP
            END

            SET @n_QtyExported = @n_QtyBalance
         END 

         UPDATE BTB_SHIPMENTDETAIL WITH (ROWLOCK)
         SET    FormNo      = @c_FormNo
               ,PermitNo    = @c_PermitNo
               ,IssuedDate  = @dt_IssuedDate
               ,IssueCountry= @c_IssueCountry  
               ,IssueAuthority = @c_IssueAuthority
               ,QtyExported = @n_QtyExported
         WHERE  BTB_ShipmentKey    = @c_BTB_ShipmentKey
         AND    BTB_ShipmentListNo = @c_BTB_ShipmentListNo
         AND    BTB_ShipmentLineNo = @c_BTB_ShipmentLineNo

         SET @n_err = @@ERROR 
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_errmsg = CONVERT(CHAR(5),@n_err)
            SET @n_err=63520
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table BTB_SHIPMENTDETAIL. (isp_BTB_Shipment_AllocFormNo)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT_SP
         END
         
         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END 
      END

      FETCH NEXT FROM @CUR_BTBSHPDET INTO @c_BTB_ShipmentListNo
                                       ,  @c_BTB_ShipmentLineNo
                                       ,  @c_FormType
                                       ,  @c_HSCode
                                       ,  @c_Storerkey
                                       ,  @c_Sku
                                       ,  @c_BTBShipItem 
                                       ,  @n_QtyExported 
   END

   IF @b_NewDetailInserted = 1
   BEGIN
      GOTO START_ALLOCATE
   END

   SELECT DISTINCT 
          SH.FormType
         ,SD.HSCode
         ,SD.Storerkey
         ,SD.Sku
         ,SD.BTBShipItem 
   INTO #TMP_EMPTYFORMNO
   FROM BTB_SHIPMENT       SH WITH (NOLOCK)  
   JOIN BTB_SHIPMENTDETAIL SD WITH (NOLOCK) ON (SH.BTB_ShipmentKey = SD.BTB_ShipmentKey)
   WHERE SD.BTB_ShipmentKey = @c_BTB_ShipmentKey
   AND   SD.FormNo = ''

   IF @@ROWCOUNT > 0
   BEGIN

      IF EXISTS ( SELECT 1 
                  FROM #TMP_EMPTYFORMNO   TMP WITH (NOLOCK)  
                  WHERE NOT EXISTS (SELECT 1
                                    FROM BTB_FTA FTA WITH (NOLOCK)
                                    WHERE FTA.FormType = TMP.FormType
                                    AND FTA.HSCode     = TMP.HSCode
                                    AND FTA.Storerkey  = TMP.Storerkey
                                    AND FTA.Sku        = TMP.Sku
                                    AND FTA.BTBShipItem= TMP.BTBShipItem 
                                    AND FTA.IssuedDate > DATEADD(day, -365, GETDATE())
	                                 AND FTA.EnabledFlag = 'Y'
                                    )
                  )
      BEGIN
         SET @b_Success = 2
         SET @c_ErrMsg = 'Form # Not Found In BTB_FTA Master file.'
      END

      IF @b_NoMatchFormNo = 1 
      BEGIN
         SET @n_QtyBalance = 0;

         WITH 
         ShipQty ( FormType, HSCode, Storerkey, Sku, BTBShipItem, QtyExported)
         AS (  SELECT DISTINCT 
                      TMP.FormType
                     ,TMP.HSCode
                     ,TMP.Storerkey
                     ,TMP.Sku
                     ,TMP.BTBShipItem 
                     ,QtyExported = ISNULL(SUM(SD.QtyExported),0)
               FROM #TMP_EMPTYFORMNO  TMP WITH (NOLOCK)
               JOIN BTB_SHIPMENT       SH WITH (NOLOCK) ON (SH.FormType  = TMP.FormType) 
               JOIN BTB_SHIPMENTDETAIL SD WITH (NOLOCK) ON (SH.BTB_ShipmentKey = SD.BTB_ShipmentKey)
                                                        AND(SD.HSCode    = TMP.HSCode )
                                                        AND(SD.Storerkey = TMP.Storerkey )
                                                        AND(SD.Sku       = TMP.Sku )
                                                        AND(SD.BTBShipItem= TMP.BTBShipItem )
               WHERE SD.BTB_ShipmentKey = @c_BTB_ShipmentKey
               GROUP BY TMP.FormType
                     ,  TMP.HSCode
                     ,  TMP.Storerkey
                     ,  TMP.Sku
                     ,  TMP.BTBShipItem
               
            )
         ,
         TotalQty ( FormType, HSCode, Storerkey, Sku, BTBShipItem, QtyBalance)
         AS (  SELECT TMP.FormType
                     ,TMP.HSCode
                     ,TMP.Storerkey
                     ,TMP.Sku
                     ,TMP.BTBShipItem
                     ,QtyBalance = ISNULL(SUM(FTA.QtyImported - FTA.QtyExported),0)
               FROM #TMP_EMPTYFORMNO  TMP WITH (NOLOCK)
               JOIN BTB_FTA           FTA WITH (NOLOCK) ON  ( FTA.FormType = TMP.FormType )
                                                        AND ( FTA.HSCode = TMP.HSCode )
                                                        AND ( FTA.Storerkey = TMP.Storerkey )
                                                        AND ( FTA.Sku = TMP.Sku )
                                                        AND ( FTA.BTBShipItem = TMP.BTBShipItem )
               AND FTA.IssuedDate > DATEADD(day, -365, GETDATE())
	            AND FTA.EnabledFlag = 'Y'
               GROUP BY TMP.FormType
                     ,  TMP.HSCode
                     ,  TMP.Storerkey
                     ,  TMP.Sku
                     ,  TMP.BTBShipItem
            )

         SELECT @n_QtyBalance = TTL.QtyBalance - SHP.QtyExported
         FROM ShipQty  SHP WITH (NOLOCK)
         JOIN TotalQty TTL WITH (NOLOCK) ON  ( SHP.FormType = TTL.FormType )
                                         AND ( SHP.HSCode = TTL.HSCode )
                                         AND ( SHP.Storerkey = TTL.Storerkey )
                                         AND ( SHP.Sku = TTL.Sku )
                                         AND ( SHP.BTBShipItem = TTL.BTBShipItem ) 
           

         IF @n_QtyBalance < 0
         BEGIN
            SET @b_Success = 2
            IF @c_ErrMsg <> ''
            BEGIN
               SET @c_ErrMsg = @c_ErrMsg + CHAR(13)
            END
            SET @c_ErrMsg = @c_ErrMsg + 'Form # Not Enough Qty.'
         END             
      END 

      IF @c_ErrMsg <> ''
      BEGIN
         SET @c_ErrMsg = 'Warning: Form # not allocated due to:' + CHAR(13) + @c_ErrMsg
      END
   END                     

QUIT_SP:

   IF CURSOR_STATUS( 'VARIABLE', '@CUR_BTBSHPDET') in (0 , 1)  
   BEGIN
      CLOSE @CUR_BTBSHPDET
      DEALLOCATE @CUR_BTBSHPDET
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BTB_Shipment_AllocFormNo'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO