SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: ispGNPOD01                                            */
/* Creation Date: 17-Jul-2014                                              */
/* Copyright: LFL                                                          */
/* Written by: Chee Jun Yan                                                */
/*                                                                         */
/* Purpose: SOS#314938-Create POD, stamp tracking number on POD.TrackCol02 */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 29-JAN-2018  Wan01     WMS-3662 - Add Externloadkey to WMS POD module*/
/***************************************************************************/
CREATE PROC [dbo].[ispGNPOD01]
(     @c_MBOLKey     NVARCHAR(10)
  ,   @c_OrderKey    NVARCHAR(10)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(250) OUTPUT
  ,   @b_Debug       INT = 0
)
AS 
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE
      @n_Continue     INT
    , @n_StartTCnt    INT

   DECLARE
      @c_Facility     NVARCHAR(5)
   ,  @c_StorerKey    NVARCHAR(15)
   ,  @c_authority    NVARCHAR(1)
   ,  @c_SMSRefKey    NVARCHAR(8)

   SET @n_Err       = 0
   SET @c_ErrMsg    = ''
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT

   IF @b_Debug = 1
   BEGIN
      SELECT 'Insert Details of MBOL into POD Table'
   END
 
   SELECT 
      @c_Facility  = Facility,
      @c_StorerKey = StorerKey
   FROM ORDERS (NOLOCK)
   WHERE OrderKey = @c_OrderKey 
   
   SET @c_authority = 0
   SET @b_Success   = 0
   EXECUTE nspGetRight
      @c_Facility,        -- facility
      @c_StorerKey,       -- Storerkey
      NULL,               -- Sku
      'PODXDeliverDate',  -- Configkey
      @b_Success    OUTPUT,
      @c_authority  OUTPUT,
      @n_Err        OUTPUT,
      @c_ErrMsg     OUTPUT


   IF @b_Success <> 1
   BEGIN
      SELECT @c_ErrMsg = 'ispGNPOD01 ' + dbo.fnc_RTrim(@c_ErrMsg)
   END
   ELSE
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM POD WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND Mbolkey = @c_MBOLKey)
      BEGIN
         INSERT INTO POD
         (  MBOLKey,          MBOLLineNumber,   LoadKey,     Externloadkey,      --(Wan01)
            OrderKey,         BuyerPO,          ExternOrderKey,
            InvoiceNo,        
            Status,           
            ActualDeliveryDate,
            InvDespatchDate,  PodDef08,         Storerkey,  SpecialHandling,
            TrackCol01,       TrackCol02 )
         SELECT
            MD.MBOLKey,   MD.MBOLLineNumber,   MD.LoadKey,
            LOADPLAN.Externloadkey,                                              --(Wan01)
            O.OrderKey,   O.BuyerPO,           O.ExternOrderKey,
            CASE WHEN wts.cnt = 1 THEN MD.userdefine01 ELSE O.InvoiceNo END, 
            '0', 
            CASE WHEN @c_authority = '1' THEN NULL ELSE GETDATE() END,
            GETDATE(),    MD.its,    O.Storerkey,    O.SpecialHandling,
            MD.UserDefine02,   CSD.TrackingNumber
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS O WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey)
            JOIN CartonShipmentDetail CSD WITH (NOLOCK) ON (O.OrderKey = CSD.OrderKey)
            JOIN LOADPLAN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LoadKey = O.LoadKey)    --(WAN01)
            -- for WATSONS-PH: use pod.invoiceno for shipping manifest#
            LEFT OUTER JOIN (SELECT storerkey, 1 AS cnt
                             FROM storerconfig WITH (NOLOCK)
                             WHERE configkey = 'WTS-ITF' and svalue = '1') AS wts
                             ON (O.storerkey = wts.storerkey)
            WHERE O.OrderKey = @c_OrderKey
              AND MD.Mbolkey = @c_MBOLKey

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_Err), @n_Err=72807
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_Err,0))
                             + ': Insert Failed On Table POD. (ispGNPOD01)'
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
      END -- IF NOT EXISTS ( SELECT 1 FROM POD WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND Mbolkey = @c_MBOLKey)
      ELSE
      BEGIN
         SELECT @c_SMSRefKey = UserDefine02
         FROM MBOLDetail WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
           AND Mbolkey = @c_MBOLKey

         IF ISNULL(@c_SMSRefKey, '') <> ''
         BEGIN
            UPDATE POD  WITH (ROWLOCK)
            Set TrackCol01 = @c_SMSRefKey,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE OrderKey = @c_OrderKey
              AND Mbolkey = @c_MBOLKey
         END
      END
   END

QUIT_SP:
   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN  
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispGNPOD01'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END
      RETURN
   END
END

GO