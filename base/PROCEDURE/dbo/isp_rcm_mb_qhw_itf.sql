SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_RCM_MB_QHW_ITF                                 */
/* Creation Date: 19-Nov-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18379 - [CN] QHW Custom Shipment trigger point          */
/*                                                                      */
/* Called By: MBOL Dynamic RCM configure at listname 'RCMConfig'        */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Nov-2021  WLChooi   1.0   DevOps Combine Script                   */
/* 10-Nov-2022  WLChooi   1.1   WMS-21162 - Change Key1 (WL01)          */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_MB_QHW_ITF]
   @c_Mbolkey  NVARCHAR(10),
   @b_success  INT           OUTPUT,
   @n_err      INT           OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_cnt       INT,
           @n_starttcnt INT

   DECLARE @c_Storerkey NVARCHAR(15),
           @c_Orderkey  NVARCHAR(10),
           @c_trmlogkey NVARCHAR(10),
           @c_Tablename NVARCHAR(50) = 'WSSOCFMLOGCH'

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err = 0

   IF EXISTS (SELECT 1
              FROM MBOL (NOLOCK)
              WHERE MbolKey = @c_Mbolkey
              AND [Status] = 9)
   BEGIN
      GOTO QUIT_SP
   END

   --WL01 S
   SELECT @c_Storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.MBOLKey = @c_Mbolkey

   --DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --SELECT OH.Orderkey, OH.Storerkey
   --FROM ORDERS OH (NOLOCK)
   --WHERE OH.MBOLKey = @c_Mbolkey

   --OPEN CUR_LOOP

   --FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_Storerkey

   --WHILE @@FETCH_STATUS <> -1

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 T2 (NOLOCK)
                     WHERE T2.tablename = @c_Tablename
                     AND T2.key1 = @c_Mbolkey   --WL01
                     AND T2.key2 = ''
                     AND T2.key3 = @c_Storerkey)
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspg_getkey
            'TransmitlogKey2'
            , 10
            , @c_trmlogkey OUTPUT
            , @b_success   OUTPUT
            , @n_err       OUTPUT
            , @c_errmsg    OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Unable to Obtain transmitlogkey. (isp_RCM_MB_QHW_ITF) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE
         BEGIN
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_TableName, @c_Mbolkey, '', @c_Storerkey, '0', '')   --WL01

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                + ': Unable to insert into Transmitlog2 table. (isp_RCM_MB_QHW_ITF) ( SQLSvr MESSAGE='
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
      ELSE   --Exists
      BEGIN
         UPDATE dbo.TRANSMITLOG2 WITH (ROWLOCK)
         SET transmitflag = '0'
         WHERE tablename = @c_TableName
         AND key1 = @c_Mbolkey   --WL01
         AND key2 = ''
         AND key3 = @c_Storerkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63840   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Update Transmitlog2 table Failed. (isp_RCM_MB_QHW_ITF) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   --   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_Storerkey
   --END
   --CLOSE CUR_LOOP
   --DEALLOCATE CUR_LOOP
   --WL01 E

QUIT_SP:
   --WL01 S
   --IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   --BEGIN
   --   CLOSE CUR_LOOP
   --   DEALLOCATE CUR_LOOP
   --END
   --WL01 E

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_QHW_ITF'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC

GO