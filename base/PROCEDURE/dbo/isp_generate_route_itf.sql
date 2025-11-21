SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Generate_Route_Itf                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Generate Routing records for interfacing                    */
/*                                                                      */
/* Called By: nep_w_loadplan_maintenance                                */
/*                                                                      */
/* Parameters: (Input)  @c_LoadKey   = Load Number                      */
/*                      @c_RouteType = Routing Type                     */
/*                                     POO-Route by PO by Order Qty     */
/*                                     POA-Route by PO by Allocated Qty */
/*                                     PTO-Route by SO by Order Qty     */
/*                                     PTA-Route by SO by Allocated Qty */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Sept-2009 NJOW01    1.1   SOS#142570-Routing Request 753          */
/*                              Enhancement. Not export if              */
/*                              orders.Issued <> 'Y'                    */
/* 24-Mar-2011  Leong     1.2   SOS# 210012 - Include Orders.Facility   */
/*                                            And LoadKey               */
/* 15-Dec-2018  TLTING01  1.3   Missing nolock                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_Generate_Route_Itf]
     @c_LoadKey    NVARCHAR(10)
   , @c_RouteType  NVARCHAR(10)
   , @b_Success    Int       OUTPUT
   , @n_Err        Int       OUTPUT
   , @c_ErrMsg     NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue Int

   DECLARE @c_RouteGroup     NVARCHAR(65)
         , @c_ExternOrderKey NVARCHAR(30)
         , @c_UserDefine05   NVARCHAR(20)
         , @c_MarkForKey     NVARCHAR(15)
         , @n_Cnt            Int
         , @c_RouteNo        NVARCHAR(6)
         , @c_RefId          NVARCHAR(25)
         , @c_TransmitLogKey NVARCHAR(10)
         , @n_StartCnt       Int
         , @c_Key3           NVARCHAR(10)
         , @c_Key2           NVARCHAR(5)
         , @c_Facility       NVARCHAR(5) -- SOS# 210012

   SELECT @n_Continue = 1, @b_Success = 1, @n_StartCnt = @@TRANCOUNT, @c_ErrMsg = '', @n_Err = 0

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT ISNULL(RTRIM(ORDERS.ExternOrderKey),'') AS ExternOrderKey
           , ISNULL(RTRIM(ORDERS.UserDefine05),'')   AS UserDefine05
           , ISNULL(RTRIM(ORDERS.MarkForKey),'')     AS MarkForKey
           , ISNULL(RTRIM(ORDERS.Facility),'')       AS Facility -- SOS# 210012
      INTO #ROUTEGROUP
      FROM LOADPLANDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.OrderKey
      WHERE LOADPLANDETAIL.Loadkey = @c_LoadKey
      AND ORDERS.Issued = 'Y'  --NJOW01
      GROUP BY ISNULL(RTRIM(ORDERS.ExternOrderKey),'')
             , ISNULL(RTRIM(ORDERS.UserDefine05),'')
             , ISNULL(RTRIM(ORDERS.MarkForKey),'')
             , ISNULL(RTRIM(ORDERS.Facility),'') -- SOS# 210012

      SET @c_RouteGroup     = ''
      SET @c_ExternOrderKey = ''
      SET @c_UserDefine05   = ''
      SET @c_MarkForKey     = ''
      SET @c_Facility       = '' -- SOS# 210012

      WHILE 1 = 1
      BEGIN
         SET ROWCOUNT  1

         SELECT @c_RouteGroup     = ExternOrderKey + UserDefine05 + MarkForKey
              , @c_ExternOrderKey = ExternOrderKey
              , @c_UserDefine05   = UserDefine05
              , @c_MarkForKey     = MarkForKey
              , @c_Facility       = Facility -- SOS# 210012
         FROM #ROUTEGROUP
         WHERE ExternOrderKey + UserDefine05 + MarkForKey > @c_RouteGroup
         ORDER BY ExternOrderKey, UserDefine05, MarkForKey

         SELECT @n_Cnt = @@ROWCOUNT

         SET ROWCOUNT  0

         IF @n_Cnt = 0
            BREAK

         IF ISNUMERIC(ISNULL(RTRIM(@c_UserDefine05),'')) <> 1 OR LEN(ISNULL(RTRIM(@c_UserDefine05),'')) > 6
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 63280
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Invalid Supplier Number. (isp_Generate_Route_Itf)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
            BREAK
         END

         IF ISNUMERIC(ISNULL(RTRIM(@c_MarkForKey),'')) <> 1 OR LEN(ISNULL(RTRIM(@c_MarkForKey),'')) > 5
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 63290
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Invalid Mark for. (isp_Generate_Route_Itf)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
            BREAK
         END

         EXECUTE dbo.nspg_getkey
                   'ITFROUTENO'
                 , 6
                 , @c_RouteNo OUTPUT
                 , @b_Success OUTPUT
                 , @n_Err     OUTPUT
                 , @c_ErrMsg  OUTPUT

         IF NOT @b_Success = 1
         BEGIN
            SELECT @n_Continue = 3
            BREAK
         END

         SELECT @c_RefId = RIGHT(REPLICATE('0',6) + RTRIM(@c_UserDefine05),6) +
                           RIGHT(REPLICATE('0',5) + RTRIM(@c_MarkForKey),5) +
                           CONVERT(Char(8),GETDATE(),112) +
                           @c_RouteNo
         --tlting01
         UPDATE LOADPLANDETAIL WITH (ROWLOCK)
         SET LOADPLANDETAIL.Userdefine01 = LEFT(@c_RefId, 11),
             LOADPLANDETAIL.Userdefine02 = SUBSTRING(@c_RefId, 12, 14),
             LOADPLANDETAIL.Trafficcop   = NULL
         FROM LOADPLANDETAIL
         JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
         WHERE ORDERS.ExternOrderKey = @c_ExternOrderKey
         AND ISNULL(RTRIM(ORDERS.UserDefine05),'') = @c_UserDefine05
         AND ISNULL(RTRIM(ORDERS.MarkForKey),'')   = @c_MarkForKey
         AND ORDERS.Issued   = 'Y' --NJOW01
         AND ORDERS.Facility = @c_Facility       -- SOS# 210012
         AND LOADPLANDETAIL.LoadKey = @c_LoadKey -- SOS# 210012

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 63300
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Update LOADPLANDETAIL TABLE Failed. (isp_Generate_Route_Itf)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
            BREAK
         END
      END -- WHILE 1 = 1
   END -- @n_Continue = 1 OR @n_Continue = 2

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT @c_Key3 = ''

      SELECT @c_Key2 = CONVERT(Char(5), COUNT(*) + 1)
      FROM TransmitLog2 WITH (NOLOCK)
      WHERE TableName = 'ROUTEREQ'
      AND key1 = @c_LoadKey

      EXEC ispGenTransmitLog2 'ROUTEREQ', @c_LoadKey, @c_Key2, @c_Key3, @c_RouteType
         , @b_Success OUTPUT
         , @n_Err     OUTPUT
         , @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SELECT @n_Continue = 3
      END
   END

   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_LogError @n_Err, @c_ErrMsg, 'isp_Generate_Route_Itf'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC

GO