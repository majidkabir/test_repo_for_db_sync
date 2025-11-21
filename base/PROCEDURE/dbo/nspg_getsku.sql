SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: nspg_GETSKU                                              */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose:                                                                  */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2012-06-26 1.0  ChewKP   Output StorerKey (ChewKP01)                      */
/* 2013-05-14 1.1  Ung      SOS276721 Fix UPC > 20 chars (ung01)             */
/* 2017-07-25 1.2  TLTING   SET Option                                       */
/*****************************************************************************/
CREATE PROC    [dbo].[nspg_GETSKU]
               @c_StorerKey   NVARCHAR(15)      OUTPUT -- (ChewKP01)
,              @c_sku         NVARCHAR(30)      OUTPUT -- (ung01)
,              @b_success     int               OUTPUT
,              @n_err         int               OUTPUT
,              @c_errmsg      NVARCHAR(250)     OUTPUT

AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue int
   SELECT @n_continue = 1
   SELECT @b_success = 1

   -- (ChewKP01)
   IF ISNULL(@c_StorerKey,'') = ''
   BEGIN
         IF NOT EXISTS (SELECT 1 FROM SKU (NOLOCK) WHERE Sku = @c_sku)
         BEGIN
            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE AltSku = @c_sku)
            BEGIN
               SELECT  @c_sku = Sku
                     , @c_StorerKey = StorerKey
               FROM SKU (NOLOCK)
               WHERE AltSku = @c_sku
               RETURN
            END

            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE RetailSku = @c_sku)
            BEGIN
               SELECT @c_sku = Sku
                    , @c_StorerKey = StorerKey
               FROM SKU (NOLOCK)
               WHERE RetailSku = @c_sku
               RETURN
            END

            -- 05-Jan-2005 YTWAN : Add in Storerkey checking - START
            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku)
            BEGIN
               SELECT @c_sku = Sku
                    , @c_StorerKey = StorerKey
               FROM SKU (NOLOCK)
               WHERE ManufacturerSku = @c_sku
               RETURN
            END

            IF NOT EXISTS (SELECT * FROM UPC (NOLOCK) WHERE UPC = @c_sku)
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=38500
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Sku (nspg_GETSKU)"
               GOTO QUIT
            END
            ELSE
            BEGIN
               SELECT @c_sku = Sku
                    , @c_StorerKey = StorerKey
               FROM UPC (NOLOCK)
               WHERE UPC = @c_sku
               GOTO QUIT
            END
            -- 05-Jan-2005 YTWAN : Add in Storerkey checking - END
         END
         ELSE
         BEGIN
            SELECT @c_StorerKey = StorerKey
            FROM dbo.SKU WITH (NOLOCK)
            WHERE SKU = @c_sku
            GOTO QUIT
         END
   END

   IF ISNULL(@c_StorerKey,'')  <> ''
   BEGIN
         IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)
         BEGIN
            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey)
            BEGIN
               SELECT @c_sku = Sku FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey
               RETURN
            END

            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey)
            BEGIN
               SELECT @c_sku = Sku FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey
               RETURN
            END

            -- 05-Jan-2005 YTWAN : Add in Storerkey checking - START
            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey)
            BEGIN
               SELECT @c_sku = Sku FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey
               RETURN
            END

            IF NOT EXISTS (SELECT * FROM UPC (NOLOCK) WHERE UPC = @c_sku and StorerKey = @c_StorerKey)
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=38500
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Sku (nspg_GETSKU)"
            END
            ELSE
            BEGIN
               SELECT @c_sku = Sku FROM UPC (NOLOCK) WHERE UPC = @c_sku and StorerKey = @c_StorerKey
            END
            -- 05-Jan-2005 YTWAN : Add in Storerkey checking - END
         END
   END

   QUIT:
   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
   END

END



GO