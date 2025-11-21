SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCalculateRSChargesWrapper                       */
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

CREATE PROCEDURE [dbo].[nspCalculateRSChargesWrapper] (
@c_StorerKeyMin     NVARCHAR(15),
@c_StorerKeyMax     NVARCHAR(15),
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
   SELECT @b_success = -1
   EXECUTE nspCalculateRSCharges
   @c_StorerKeyMin ,
   @c_StorerKeyMax ,
   @c_ChargeTypes  ,
   @dt_CutOffDate  ,
   @b_success         OUTPUT,
   @n_err             OUTPUT,
   @c_errmsg          OUTPUT,
   @n_totinvoices     OUTPUT,
   @n_totcharges      OUTPUT
   SELECT @b_success, @n_err, @c_errmsg, @n_totcharges
END


GO