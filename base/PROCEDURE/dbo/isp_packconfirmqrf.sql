SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackConfirmQRF                                      */
/* Creation Date: 2020-AUG-06                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-14315 - [CN] NIKE_O2_Ecom Packing_CR                    */
/*        :                                                             */
/* Called By: isp_Ecom_Packconfirm                                      */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-12-23  Wan01    1.1   WMS-15244 -[CN] NIKE_O2_Ecom_packing_RFID_CR */
/************************************************************************/
CREATE PROC [dbo].[isp_PackConfirmQRF]
           @c_PickSlipNo   NVARCHAR(10)
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         
         , @n_CartonNo        INT = 0           --(Wan01)
         , @n_QRFGroupKey     INT = 0           --(Wan01)
         , @c_LabelLine       NVARCHAR(5)       --(Wan01)

         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_ExternOrderkey  NVARCHAR(50) = ''
         , @c_UserDefine03    NVARCHAR(20) = ''
         , @c_M_Company       NVARCHAR(45) = ''
         , @c_OrderStatus     NVARCHAR(10) = ''
         , @c_Source          NVARCHAR(10) = 'LF'

         , @c_OrderLineNumber NVARCHAR(5)  = ''
         , @c_ExternLineNo    NVARCHAR(10) = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Sku             NVARCHAR(20) = ''
         , @c_labelNo         NVARCHAR(20) = ''
         , @c_QRCode          NVARCHAR(100)= '' 
         , @c_RFIDNo          NVARCHAR(100)= ''
         , @c_TIDNo           NVARCHAR(100)= ''

         , @dt_ScanQRDate     DATETIME     = ''
                 
         , @cur_PQRF          CURSOR 
         
         , @cur_PQRFGRP       CURSOR         --(Wan01)
         
   DECLARE @TORDERDETAIL      TABLE
      (  OrderLineNumber   NVARCHAR(5)    NOT NULL PRIMARY KEY
      ,  ExternLineNo      NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  QtyAllocated      INT            NOT NULL DEFAULT(0) 
      )         

   DECLARE @TPACKQRF          TABLE             --(Wan01) - START                      
      (  RowRef            INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  PickSlipNo        NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  CartonNo          INT            NOT NULL DEFAULT(0)   
      ,  LabelLine         NVARCHAR(5)    NOT NULL DEFAULT('')          
      ,	QRCode            NVARCHAR(100)  NOT NULL DEFAULT('')
      ,  RFIDNo            NVARCHAR(100)  NOT NULL DEFAULT('')
      ,  TIDNo             NVARCHAR(100)  NOT NULL DEFAULT('')
      ,  QRFGroupKey       INT            NOT NULL DEFAULT(0) 
      )                                         --(Wan01) - END
      
   SELECT @c_Orderkey = PH.Orderkey
   FROM PACKHEADER PH   WITH (NOLOCK) 
   WHERE PH.PickSlipNo = @c_PickSlipNo

   --2020-08-21 - Fixed
   IF NOT EXISTS (SELECT 1   
                  FROM PACKQRF QRF  WITH (NOLOCK) 
                  WHERE QRF.PickSlipNo = @c_PickSlipNo
                  )
   BEGIN
      GOTO QUIT_SP
   END
   
   --IF packConfirm after Undo PackConfirm, Do not need to Insert data again
   IF EXISTS ( SELECT 1
               FROM EXTERNORDERS EO WITH (NOLOCK)
               WHERE EO.Orderkey = @c_Orderkey
             )
   BEGIN
      GOTO QUIT_SP
   END

   SELECT TOP 1 @dt_ScanQRDate = PQRF.AddDate
   FROM PACKQRF PQRF WITH (NOLOCK)
   WHERE PQRF.PickSlipNo = @c_PickSlipNo
   ORDER BY PQRF.PackQRFKey

   SELECT @c_Storerkey = OH.Storerkey
      ,   @c_ExternOrderkey = ISNULL(OH.ExternOrderkey,'')
      ,   @c_UserDefine03  = ISNULL(OH.UserDefine03,'')
      ,   @c_M_Company = ISNULL(OH.M_Company,'')
      ,   @c_OrderStatus = ISNULL(OH.[Status],'')
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey

   INSERT INTO EXTERNORDERS   
      (  ExternOrderKey 
      ,  OrderKey       
      ,  Storerkey      
      ,  Source         
      ,  [Status]         
      ,  BindingDate
      ,  PlatformName
      ,  PlatformOrderNo 
      )
   VALUES
      ( 
         @c_ExternOrderKey 
      ,  @c_OrderKey       
      ,  @c_Storerkey      
      ,  @c_Source         
      ,  @c_OrderStatus         
      ,  @dt_ScanQRDate
      ,  @c_UserDefine03
      ,  @c_M_Company 
      )  

   SET @n_err = @@ERROR      
         
   IF @n_err <> 0      
   BEGIN      
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(char(250),@n_err)
      SET @n_err = 81010
      SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Insert Failed into Table ExternOrders. (isp_PackConfirmQRF)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
      GOTO QUIT_SP
   END  

   INSERT INTO @TORDERDETAIL
      (  
         OrderLineNumber
      ,  ExternLineNo
      ,  Sku
      ,  QtyAllocated
      )
   SELECT OD.OrderLineNumber
         ,OD.ExternLineNo
         ,OD.Sku
         ,OD.QtyAllocated
   FROM ORDERDETAIL OD WITH (NOLOCK)
   WHERE OD.Orderkey = @c_Orderkey

   --(Wan01) - START
   INSERT INTO @TPACKQRF
      (  PickSlipNo
      ,  CartonNo
      ,  LabelLine
      ,  QRCode
      ,  RFIDNo
      ,  TIDNo
      ,  QRFGroupKey
      ) 
   SELECT PQRF.PickSlipNo
         ,PQRF.CartonNo
         ,PQRF.LabelLine
         ,PQRF.QRCode
         ,PQRF.RFIDNo
         ,PQRF.TIDNo
         ,PQRF.QRFGroupKey
   FROM PackQRF PQRF WITH (NOLOCK)
   WHERE PQRF.PickSlipNo = @c_PickSlipNo
   ORDER BY PQRF.PickSlipNo
         ,  PQRF.CartonNo
         ,  PQRF.LabelLine
         ,  PQRF.QRFGroupKey
         ,  PQRF.PackQRFKey 
         
   SET @cur_PQRFGRP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          PD.Storerkey
         ,PD.Sku
         ,PD.labelNo
         ,PD.CartonNo
         ,PD.LabelLine    
         ,PQRF.QRFGroupKey
   FROM PACKDETAIL PD (NOLOCK)
   JOIN @TPACKQRF PQRF ON PD.PickSlipNo = PQRF.PickSlipNo 
                      AND PD.CartonNo   = PQRF.CartonNo 
                      AND PD.LabelLine  = PQRF.LabelLine
   WHERE PD.PickSlipNo = @c_PickSlipNo
   ORDER BY PD.CartonNo
         ,  PD.LabelLine
         ,  PQRF.QRFGroupKey         

   OPEN @cur_PQRFGRP  
          
   FETCH NEXT FROM @cur_PQRFGRP INTO   @c_Storerkey
                                    ,  @c_Sku
                                    ,  @c_labelNo
                                    ,  @n_CartonNo
                                    ,  @c_LabelLine
                                    ,  @n_QRFGroupKey
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      SET @c_OrderLineNumber = ''
      SET @c_ExternLineNo = ''

      SELECT TOP 1 
               @c_OrderLineNumber = T.OrderLineNumber
            ,  @c_ExternLineNo = ISNULL(T.ExternLineNo,'')
      FROM @TORDERDETAIL T
      WHERE Sku = @c_Sku
      AND QtyAllocated > 0
      ORDER BY T.OrderLineNumber

      SET @cur_PQRF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PQRF.QRCode
            ,PQRF.RFIDNo
            ,PQRF.TIDNo 
      FROM @TPACKQRF PQRF 
      WHERE PQRF.PickSlipNo = @c_PickSlipNo
      AND PQRF.CartonNo   = @n_CartonNo 
      AND PQRF.LabelLine  = @c_LabelLine
      AND PQRF.QRFGroupKey= @n_QRFGroupKey   
      ORDER BY PQRF.RowRef

      OPEN @cur_PQRF  
          
      FETCH NEXT FROM @cur_PQRF INTO   @c_QRCode
                                    ,  @c_RFIDNo
                                    ,  @c_TIDNo 
      WHILE @@FETCH_STATUS <> -1 
      BEGIN                        
         INSERT INTO EXTERNORDERSDETAIL   
            (   
               OrderKey       
            ,  Orderlinenumber
            ,  ExternOrderKey 
            ,  ExternLineNo   
            ,  QRCode         
            ,  Storerkey      
            ,  SKU            
            ,  RFIDNo         
            ,  TIDNo 
            ,  UserDefine01         
            ,  [Status] 
            )        
         VALUES
            ( 
               @c_OrderKey       
            ,  @c_Orderlinenumber
            ,  @c_ExternOrderKey 
            ,  @c_ExternLineNo   
            ,  @c_QRCode         
            ,  @c_Storerkey      
            ,  @c_SKU            
            ,  @c_RFIDNo         
            ,  @c_TIDNo
            ,  @c_labelNo          
            ,  @c_OrderStatus 
            )  

         SET @n_err = @@ERROR      
         
         IF @n_err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 81020
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table ExternOrdersDetail. (isp_PackConfirmQRF)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
            BREAK
         END 
         FETCH NEXT FROM @cur_PQRF INTO   @c_QRCode
                                       ,  @c_RFIDNo
                                       ,  @c_TIDNo  
      END
      CLOSE @cur_PQRF
      DEALLOCATE @cur_PQRF

      UPDATE @TORDERDETAIL 
         SET QtyAllocated = QtyAllocated - 1
      WHERE OrderLineNumber = @c_OrderLineNumber
      AND Sku = @c_Sku
      AND QtyAllocated > 0

      FETCH NEXT FROM @cur_PQRFGRP INTO   @c_Storerkey
                                       ,  @c_Sku
                                       ,  @c_labelNo
                                       ,  @n_CartonNo
                                       ,  @c_LabelLine
                                       ,  @n_QRFGroupKey
   END
   CLOSE @cur_PQRFGRP
   DEALLOCATE @cur_PQRFGRP
   --(Wan01)
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackConfirmQRF'
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