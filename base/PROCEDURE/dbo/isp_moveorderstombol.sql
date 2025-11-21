SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_MoveOrdersToMBOL                               */
/* Creation Date: 05-JUL-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#249041-FNPC Configkey-Move ORders to new/other MBOL     */
/*                                                                      */
/* Called By: w_popup_mboldetail - ue_move()                            */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18-09-2012   Leong     1.1   SOS# 256603 - Bug Fix                   */
/*                                          - Not allow to move between */
/*                                            different MBOL.Facility.  */
/*                                          - Not allow multi storer.   */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_MoveOrdersToMBOL]
      @c_MBOLKey        NVARCHAR(10)
   ,  @c_MBOLlineNumber NVARCHAR(5)
   ,  @c_ToMBOLKey      NVARCHAR(10) OUTPUT
   ,  @b_success        INT         OUTPUT
   ,  @n_err            INT         OUTPUT
   ,  @c_errmsg         CHAR(225)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_starttcnt       INT
         , @n_createnew       INT

   DECLARE @c_Facility        NVARCHAR(5)
         , @c_Orderkey        NVARCHAR(10)
         , @c_ExternOrderkey  NVARCHAR(50)  --tlting_ext
         , @c_Loadkey         NVARCHAR(10)
         , @c_Description     NVARCHAR(30)
         , @c_Route           NVARCHAR(10)
         , @dt_Orderdate      DATETIME
         , @dt_DeliveryDate   DATETIME
         , @dt_DeliveryTime   DATETIME

         , @c_InvoiceStatus   NVARCHAR(10)
         , @c_OfficialReceipt NVARCHAR(12)
         , @c_PCMNum          NVARCHAR(12)

         , @n_Cube            FLOAT
         , @n_Weight          FLOAT

         , @n_TotalCartons    INT
         , @c_ExternReason    NVARCHAR(60)
         , @c_UserDefine01    NVARCHAR(20)
         , @c_UserDefine02    NVARCHAR(20)
         , @c_UserDefine03    NVARCHAR(20)
         , @c_UserDefine04    NVARCHAR(20)
         , @c_UserDefine05    NVARCHAR(20)
         , @dt_UserDefine06   DATETIME
         , @dt_UserDefine07   DATETIME
         , @c_UserDefine08    NVARCHAR(20)
         , @c_UserDefine09    NVARCHAR(20)
         , @c_UserDefine10    NVARCHAR(20)
         , @c_ToFacility      NVARCHAR(5)  -- SOS# 256603
         , @c_StorerKey       NVARCHAR(15) -- SOS# 256603
         , @c_ToStorerKey     NVARCHAR(15) -- SOS# 256603
         , @c_DisAllowMultiStorer NVARCHAR(30) -- SOS# 256603

   SET @n_continue = 1
   SET @n_starttcnt= @@TRANCOUNT
   SET @n_createnew= 0

   SET @c_Facility          = ''
   SET @c_ToFacility        = ''

   SET @c_StorerKey         = ''
   SET @c_ToStorerKey       = ''

   SET @c_DisAllowMultiStorer = '0'

   SET @c_Orderkey          = ''
   SET @c_ExternOrderkey    = ''
   SET @c_Loadkey           = ''
   SET @c_Description       = ''
   SET @c_Route             = ''
   SET @c_InvoiceStatus     = ''
   SET @c_OfficialReceipt   = ''
   SET @c_PCMNum            = ''
   SET @n_Cube              = 0.00
   SET @n_Weight            = 0.00
   SET @n_TotalCartons      = 0
   SET @c_ExternReason      = ''
   SET @c_UserDefine01      = ''
   SET @c_UserDefine02      = ''
   SET @c_UserDefine03      = ''
   SET @c_UserDefine04      = ''
   SET @c_UserDefine05      = ''
   SET @c_UserDefine08      = ''
   SET @c_UserDefine09      = ''
   SET @c_UserDefine10      = ''

   SELECT @c_DisAllowMultiStorer = ISNULL(RTRIM(NSQLValue),'')
   FROM NSQLCONFIG WITH (NOLOCK)
   WHERE ConfigKey = 'DisAllowMultiStorerOnMBOL'

   SELECT @c_Facility = ISNULL(RTRIM(Facility),'')
   FROM MBOL WITH (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey

   SELECT @c_StorerKey = MIN(StorerKey)
   FROM ORDERS WITH (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey

   IF ISNULL(RTRIM(@c_ToMBOLKey),'') <> '' -- SOS# 256603
   BEGIN
      SELECT @c_ToFacility = ISNULL(RTRIM(Facility),'')
      FROM MBOL WITH (NOLOCK)
      WHERE MBOLKey = @c_ToMBOLKey

      IF ISNULL(RTRIM(@c_Facility),'') <> ISNULL(RTRIM(@c_ToFacility),'')
      BEGIN
         SET @n_continue = 3
         SET @n_err = 30107
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Different facility is not allowed. (isp_MoveOrdersToMBOL)'
         GOTO QUIT
      END

      IF @c_DisAllowMultiStorer = '1'
      BEGIN
         SELECT @c_ToStorerKey = MIN(StorerKey)
         FROM ORDERS WITH (NOLOCK)
         WHERE MBOLKey = @c_ToMBOLKey

         IF ISNULL(RTRIM(@c_StorerKey),'') <> ISNULL(RTRIM(@c_ToStorerKey),'')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30108
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Multi Storer is not allowed. (isp_MoveOrdersToMBOL)'
            GOTO QUIT
         END
      END
   END

   SELECT  @c_Orderkey       = MD.Orderkey
         , @c_ExternOrderkey = ISNULL(RTRIM(MD.ExternOrderkey),'')
         , @c_Loadkey        = ISNULL(RTRIM(MD.Loadkey),'')
         , @c_Route          = ISNULL(RTRIM(OH.Route),'')
         , @dt_Orderdate     = MD.Orderdate
         , @dt_Deliverydate  = MD.Deliverydate
         , @dt_DeliveryTime  = MD.DeliveryTime
         , @c_InvoiceStatus  = ISNULL(RTRIM(MD.InvoiceStatus),'')
         , @c_OfficialReceipt= ISNULL(RTRIM(MD.OfficialReceipt),'')
         , @c_PCMNum         = ISNULL(RTRIM(MD.PCMNum),'')
         , @n_Cube           = ISNULL(MD.Cube,0)
         , @n_Weight         = ISNULL(MD.Weight,0)
         , @n_TotalCartons   = ISNULL(MD.TotalCartons,0)
         , @c_ExternReason   = ISNULL(RTRIM(MD.ExternReason),'')
         , @c_UserDefine01   = ISNULL(RTRIM(MD.UserDefine01),'')
         , @c_UserDefine02   = ISNULL(RTRIM(MD.UserDefine02),'')
         , @c_UserDefine03   = ISNULL(RTRIM(MD.UserDefine03),'')
         , @c_UserDefine04   = ISNULL(RTRIM(MD.UserDefine04),'')
         , @c_UserDefine05   = ISNULL(RTRIM(MD.UserDefine05),'')
         , @dt_UserDefine06  = MD.UserDefine06
         , @dt_UserDefine07  = MD.UserDefine07
         , @c_UserDefine08   = ISNULL(RTRIM(MD.UserDefine08),'')
         , @c_UserDefine09   = ISNULL(RTRIM(MD.UserDefine09),'')
         , @c_UserDefine10   = ISNULL(RTRIM(MD.UserDefine10),'')
         , @c_Description    = ISNULL(RTRIM(MD.Description),'')-- SOS# 256603
   FROM MBOLDETAIL MD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   WHERE MD.MBOLKey = @c_MBOLKey
   AND   MD.MBOLlineNumber = @c_MBOLlineNumber

   IF ISNULL(RTRIM(@c_ToMBOLKey),'') = ''
   BEGIN
      EXECUTE nspg_GetKey
           'MBOL'
         , 10
         , @c_ToMBOLKey  OUTPUT
         , @b_success    OUTPUT
         , @n_err        OUTPUT
         , @c_errmsg     OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 30100
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getting New MBOLKey. (isp_MoveOrdersToMBOL)'
         GOTO QUIT
      END
      SET @n_createnew = 1
   END

   BEGIN TRAN
   DELETE MBOLDetail
   WHERE MBOLKey = @c_MBOLKey
   AND   MBOLLineNumber = @c_MBOLlineNumber

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30101
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Delete MBOLDetail. (isp_MoveOrdersToMBOL)'
      GOTO QUIT
   END

   IF @n_createnew = 1
   BEGIN
      INSERT INTO MBOL (Facility, MBOLkey)
      VALUES (@c_Facility, @c_ToMBOLKey)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 30102
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert MBOL Table. (isp_MoveOrdersToMBOL)'
         GOTO QUIT
      END
   END

   EXEC isp_InsertMBOLDetail
        @c_ToMBOLKey
      , @c_Facility
      , @c_OrderKey
      , @c_LoadKey
      , @n_Weight
      , @n_Cube
      , @c_ExternOrderkey
      , @dt_Orderdate
      , @dt_Deliverydate
      , @c_Route
      , @b_Success   OUTPUT
      , @n_err       OUTPUT
      , @c_errmsg    OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30103
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert MBOLDetail Table. (isp_MoveOrdersToMBOL)'
      GOTO QUIT
   END

   UPDATE MBOLDETAIL WITH (ROWLOCK)
   SET  Description     = @c_Description
      , DeliveryDate    = @dt_DeliveryDate
      , DeliveryTime    = @dt_DeliveryTime
      , InvoiceStatus   = @c_InvoiceStatus
      , OfficialReceipt = @c_OfficialReceipt
      , PCMNum          = @c_PCMNum
      , ExternReason    = @c_ExternReason
      , TotalCartons    = @n_TotalCartons
      , UserDefine01    = @c_UserDefine01
      , UserDefine02    = @c_UserDefine02
      , UserDefine03    = @c_UserDefine03
      , UserDefine04    = @c_UserDefine04
      , UserDefine05    = @c_UserDefine05
      , UserDefine06    = @dt_UserDefine06
      , UserDefine07    = @dt_UserDefine07
      , UserDefine08    = @c_UserDefine08
      , UserDefine09    = @c_UserDefine09
      , UserDefine10    = @c_UserDefine10
      , EditWho         = SUSER_NAME()
      , EditDate        = GETDATE()
      , TrafficCop      = NULL
   WHERE MBOLKey = @c_ToMBOLKey
   AND   Orderkey= @c_Orderkey

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30104
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update MBOLDETAIL Table. (isp_MoveOrdersToMBOL)'
      GOTO QUIT
   END

   UPDATE ORDERS WITH (ROWLOCK)
   SET   MBOLKey = @c_ToMBOLKey
      ,  EditWho = SUSER_NAME()
      ,  EditDate= GETDATE()
      ,  Trafficcop = NULL
   WHERE Orderkey = @c_Orderkey

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30105
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_MoveOrdersToMBOL)'
      GOTO QUIT
   END

   UPDATE ORDERDETAIL WITH (ROWLOCK)
   SET   MBOLKey = @c_ToMBOLKey
      ,  EditWho = SUSER_NAME()
      ,  EditDate= GETDATE()
      ,  Trafficcop = NULL
   WHERE Orderkey = @c_Orderkey

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30106
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_MoveOrdersToMBOL)'
      GOTO QUIT
   END

   QUIT:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
           COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_MoveOrdersToMBOL'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 -- SOS# 256603
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
       COMMIT TRAN
      END
      RETURN
   END
END

GO