SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillingRunWrapper                               */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspBillingRunWrapper] (
@c_BillingGroupMin  NVARCHAR(15),
@c_BillingGroupMax  NVARCHAR(15),
@c_ChargeTypes      NVARCHAR(250),
@dt_CutOffDate      datetime   )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err      int,
   @b_success     int,
   @c_errmsg      NVARCHAR(250),
   @n_totinvoices int,
   @n_totcharges  int
   SELECT @b_success = -1,
   @n_totinvoices = 0,
   @n_totcharges  = 0
   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      select 'Billing Run Wrapper', @c_BillingGroupMin ,@c_BillingGroupMax ,@c_ChargeTypes  , @dt_CutOffDate
   END
   EXECUTE nspBillingRun
   @c_BillingGroupMin ,
   @c_BillingGroupMax ,
   @c_ChargeTypes  ,
   @dt_CutOffDate  ,
   @b_success         OUTPUT,
   @n_err             OUTPUT,
   @c_errmsg          OUTPUT,
   @n_totinvoices     OUTPUT,
   @n_totcharges      OUTPUT
   IF @b_debug = 1
   BEGIN
      select 'Billing Run Completed', '@n_totinvoices'=@n_totinvoices,
      '@n_totcharges'=@n_totcharges,
      '@b_success'=@b_success,
      '@n_err'=@n_err,
      '@c_errmsg'=@c_errmsg
   END
   SELECT @b_success, @n_err, @c_errmsg, @n_totinvoices, @n_totcharges
END


GO