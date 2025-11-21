SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspg_GETSKUBUSR                                    */
/* Creation Date: 12-Oct-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: Generic Get BUSR fields in SKU table                        */
/*                                                                      */
/* Parameters: @c_BUSRValue is being setup in Codelkup.Code and         */ 
/*             @c_BusrNo is being setup in Codelkup.Long          	   */
/*             Setup Codelkup.Short with Storerkey where                */
/*             Codelkup.Listname = 'PNPEXCBUSR'                         */
/*                                                                   	*/
/* PVCS Version: 1.0  	                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 27-Jul-2017  TLTING 1.1 SET Option                                   */
/*                                                                      */
/************************************************************************/

CREATE PROC    [dbo].[nspg_GETSKUBUSR]
               @c_StorerKey   NVARCHAR(15)
,              @c_sku         NVARCHAR(20)
,              @c_BUSRValue   NVARCHAR(30)
,              @c_BusrNo      NVARCHAR(30)
,              @c_BusrFlag    NVARCHAR(1)          OUTPUT
,              @b_success     int              OUTPUT
,              @n_err         int              OUTPUT
,              @c_errmsg      NVARCHAR(250)        OUTPUT

AS

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue int
   SELECT @n_continue = 1
   SELECT @b_success  = 1
   SELECT @c_BusrFlag  = 'N'

   IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)
   BEGIN
         SELECT @n_continue=3
         SELECT @n_err=68500
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Sku (nspg_GETSKUBUSR)"
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_BusrNo = 'BUSR1'
      BEGIN
		   IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR1 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END
      ELSE IF @c_BusrNo = 'BUSR2'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR2 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR3'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR3 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR4'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR4 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR5'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR5 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR6'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR6 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR7'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR7 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR8'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR8 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR9'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR9 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
      ELSE IF @c_BusrNo = 'BUSR10'
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey AND BUSR10 = @c_BUSRValue)
		   BEGIN
		      SELECT @c_BusrFlag = 'Y'
		   END
      END 
   END
	
   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
   END

END


GO