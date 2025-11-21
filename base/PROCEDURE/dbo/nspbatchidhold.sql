SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBatchIDHold                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.     Purposes                              */
/* 23-Mar-2021  WLChooi  1.1      Comment out code due to ARCHIVE DB    */
/*                                name and IdOnHold table are not exists*/
/*                                in Production (WL01)                  */
/************************************************************************/

CREATE PROC    [dbo].[nspBatchIDHold]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err int
   DECLARE @c_errmsg NVARCHAR(255),
   @c_ToId   NVARCHAR(10),
   @b_Success int,
   @n_continue int
   SELECT @n_continue = 1

   --WL01 S
   --ARCHIVE db name and IdOnHold table are not exists in production. 
   --This stored proc might not valid anymore. 
   --IF ( @n_continue = 1 or @n_continue = 2)
   --BEGIN
   --   SELECT @c_ToID = " "
   --   SET ROWCOUNT 1
   --   WHILE (1 = 1)
   --   BEGIN
   --      SET ROWCOUNT 1
   --      SELECT @c_ToID = ID
   --      FROM Archive..IdOnHold
   --      WHERE ID > @c_ToId
   --      ORDER BY ID
   --      IF @@ROWCOUNT = 0
   --      BEGIN
   --         SET ROWCOUNT 0
   --         BREAK
   --      END
   --      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) is NOT NULL
   --      BEGIN
   --         SELECT "Hold id", @c_toid
   --         SELECT @b_success = 0
   --         EXECUTE nspInventoryHold
   --         ""
   --         , ""
   --         , @c_toid
   --         , "QC"
   --         , "1"
   --         , @b_Success OUTPUT
   --         , @n_err OUTPUT
   --         , @c_errmsg OUTPUT
   --         IF @b_success <> 1
   --         BEGIN
   --            SELECT @n_continue=3
   --         END
   --      END
   --   END
   --END
   --WL01 E
END

GO