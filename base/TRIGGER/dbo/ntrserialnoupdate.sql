SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Trigger: ntrSerialNoUpdate                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:  KHLIM                                                   */
/*                                                                      */
/* Purpose:  SerialNo Update                                            */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 28-Oct-2013  TLTING        Review Editdate column update             */
/* 19-SEP-2-17  Wan01   1.1   WMS-2931 - CN_DYSON_EXCEED_Serialno_CR    */
/* 18-Nov-2017  Leong   1.2   Revise error message. (L01).              */
/* 20-Nov-2017  Wan02   1.2   Fixed to filter by sku                    */
/*************************************************************************/

CREATE TRIGGER [dbo].[ntrSerialNoUpdate]
ON  [dbo].[SerialNo] FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err        int       -- Error number returned by stored procedure or this trigger
         , @n_err2       int       -- For Additional Error Detection
         , @c_errmsg     char(250) -- Error message returned by stored procedure or this trigger
         , @n_continue   int
         , @n_starttcnt  int       -- Holds the current transaction count
         , @c_preprocess char(250) -- preprocess
         , @c_pstprocess char(250) -- post process
         , @n_cnt        int

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

    /* #INCLUDE <TRTHU1.SQL> */


   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE SerialNo
      SET EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      FROM SerialNo (NOLOCK), INSERTED (NOLOCK)
      WHERE SerialNo.SerialNoKey = INSERTED.SerialNoKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SerialNo. (ntrSerialNoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   --(Wan01) - START

   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
   END

   DECLARE @c_SerialNoKey  NVARCHAR(10)
         , @c_SerialNo     NVARCHAR(30)
         , @c_Status_INS   NVARCHAR(10)
         , @c_Status_DEL   NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @c_SNStatus     NVARCHAR(10)
         , @c_ORDStatus    NVARCHAR(10)

         , @b_Reject       INT

    DECLARE @cur_SN        CURSOR
         ,  @cur_CL        CURSOR

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SET @cur_SN = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT I.SerialNoKey
            ,I.SerialNo
            ,I.Storerkey
            ,I.Sku
            ,I.Status
            ,D.Status
      FROM INSERTED I WITH (NOLOCK)
      JOIN DELETED D WITH (NOLOCK) ON (I.SerialNoKey = D.SerialNoKey )
      WHERE I.Status <> D.Status

      OPEN @cur_SN

      FETCH NEXT FROM @cur_SN INTO @c_SerialNoKey, @c_SerialNo, @c_Storerkey, @c_Sku, @c_Status_INS, @c_Status_DEL

      WHILE @@FETCH_STATUS = 0 AND @n_Continue = 1
      BEGIN
         IF @n_Continue = 1
         BEGIN
            SET @c_SNStatus = '9' -- Open/Shipped

            SET @n_Cnt = 0
            SELECT @n_Cnt = 1
            FROM PACKSERIALNO PSN WITH (NOLOCK)
            JOIN PACKHEADER   PH  WITH (NOLOCK) ON (PSN.PickSlipNo = PH.PickSlipNo)
            WHERE PSN.Storerkey = @c_Storerkey
            AND   PSN.SerialNo  = @c_SerialNo
            AND   PSN.Sku = @c_Sku                    --(Wan02)
            AND   PH.Status < '9'

            IF @n_Cnt = 1
            BEGIN
               SET @c_SNStatus = '1' -- Packing Progress
            END

            IF @n_Cnt = 0
            BEGIN
               SET @c_SNStatus = '9' -- Open/Shipped
               -- Check Orders Shipment By Orderkey   - Discrete Pack
               SELECT @n_Cnt       = COUNT(1)
                     ,@c_ORDStatus = ISNULL(MIN(OH.Status),0)
               FROM PACKSERIALNO PSN WITH (NOLOCK)
               JOIN PACKHEADER   PH  WITH (NOLOCK) ON (PSN.PickSlipNo = PH.PickSlipNo)
               JOIN ORDERS       OH  WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
               WHERE PSN.Storerkey = @c_Storerkey
               AND   PSN.SerialNo  = @c_SerialNo
               AND   PSN.Sku = @c_Sku                 --(Wan02)
               AND   PH.Orderkey <> ''
               GROUP BY PH.Orderkey                   --(Wan02)
               HAVING ISNULL(MIN(OH.Status),0) < '9'  --(Wan02)

               IF @n_Cnt >= 1 AND @c_ORDStatus < '9'  --(Wan02)
               BEGIN
                  SET @c_SNStatus = '6' -- Pending Shipment Progress
               END

               IF @n_Cnt = 0
               BEGIN
                  -- Check Orders Shipment By Loadkey - Consolidate Pack
                  SELECT @n_Cnt       = COUNT(1)
                        ,@c_ORDStatus = ISNULL(MIN(OH.Status),0)
                  FROM PACKSERIALNO PSN WITH (NOLOCK)
                  JOIN PACKHEADER   PH  WITH (NOLOCK) ON (PSN.PickSlipNo = PH.PickSlipNo)
                  JOIN ORDERS       OH  WITH (NOLOCK) ON (PH.Loadkey = OH.Loadkey)
                  WHERE PSN.Storerkey = @c_Storerkey
                  AND   PSN.SerialNo  = @c_SerialNo
                  AND   PSN.Sku       = @c_Sku           --(Wan02)
                  AND   PH.Orderkey   = ''
                  GROUP BY PH.Loadkey                    --(Wan02)     
                  HAVING ISNULL(MIN(OH.Status),0) < '9'  --(Wan02)
               END

               IF @n_Cnt >= 1 AND @c_ORDStatus < '9'     --(Wan02)    
               BEGIN
                  SET @c_SNStatus = '6' -- Pending Shipment Progress
               END
            END

            SET @b_Reject = 0
            IF @c_SNStatus = '1' AND @c_Status_INS NOT IN( '1' )
            BEGIN
               SET @b_Reject = 1
            END

            IF @c_SNStatus = '6' AND @c_Status_INS NOT IN( '6' )
            BEGIN
               SET @b_Reject = 1
            END

            IF @c_SNStatus = '9' AND @c_Status_INS NOT IN ( '0', '1', 'H', 'CANC', '9') --L01 (Temp)
            BEGIN
               SET @b_Reject = 1
            END
            
            IF @b_Reject = 1
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 69710
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': SN:' + ISNULL(RTRIM(@c_SerialNo),'') + '/' +
                              ISNULL(RTRIM(@c_SNStatus),'') + '/' + ISNULL(RTRIM(@c_Status_INS),'') + '/' +
                              ISNULL(RTRIM(@c_Storerkey),'')+ '/' + ISNULL(RTRIM(@c_Sku),'') +
                              '. Invalid Status Change. Change Abort.(ntrSerialNoUpdate)' -- L01
            END
         END
         FETCH NEXT FROM @cur_SN INTO @c_SerialNoKey, @c_SerialNo, @c_Storerkey, @c_Sku, @c_Status_INS, @c_Status_DEL
      END
   END
   --(Wan01) - END


   /* #INCLUDE <TRTHU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrSerialNoUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO