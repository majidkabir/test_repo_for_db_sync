SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTransferRegister                                */
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
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/************************************************************************/

CREATE PROCedure [dbo].[nspTransferRegister] (
@c_storer_start NVARCHAR(18),
@c_storer_end NVARCHAR(18),
@c_doc_start NVARCHAR(10),
@c_doc_end NVARCHAR(10),
@d_date_start NVARCHAR(8),
@d_date_end NVARCHAR(8)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- extract eligible transfer records
   SELECT TRANSFER.TransferKey,
   TRANSFER.FromStorerKey,
   TRANSFER.CustomerRefNo,
   TRANSFER.Remarks,
   STORER.Company,
   TRANSFER.EffectiveDate,
   TRANSFERDETAIL.Lottable03,
   TRANSFERDETAIL.ToLottable03,
   TRANSFERDETAIL.FromSku,
   SKU.Descr,
   TRANSFERDETAIL.FromUOM,
   TRANSFERDETAIL.Lottable02,
   TRANSFERDETAIL.Lottable04,
   TRANSFERDETAIL.FromLoc,
   TRANSFERDETAIL.FromQty,
   TRANSFERDETAIL.ToSku,
   TRANSFERDETAIL.ToLoc,
   TRANSFERDETAIL.ToQty,
   TRANSFER.PrintFlag
   FROM TRANSFER (NOLOCK),
   TRANSFERDETAIL (NOLOCK),
   SKU (NOLOCK),
   STORER (NOLOCK)
   WHERE (TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey) AND
   (TRANSFER.FromStorerKey BETWEEN @c_storer_start AND @c_storer_end) AND
   (TRANSFER.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
   (TRANSFER.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end))) AND
   (TRANSFERDETAIL.FromSku = SKU.sku) AND
   (TRANSFERDETAIL.FromStorerkey = STORER.Storerkey) AND
   (TRANSFER.PrintFlag = 'N')
   --		((sUser_sName() IN ('dbo','chicoone','nagramic1')) OR (TRANSFER.PrintFlag = 'N'))
   -- update printflag to 'Y' of all records selected
   UPDATE TRANSFER
   SET TrafficCop = NULL, PrintFlag = 'Y'
   FROM TRANSFER (NOLOCK),
   TRANSFERDETAIL (NOLOCK),
   SKU (NOLOCK),
   STORER (NOLOCK)
   WHERE (TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey) AND
   (TRANSFER.FromStorerKey BETWEEN @c_storer_start AND @c_storer_end) AND
   (TRANSFER.CustomerRefNo BETWEEN @c_doc_start AND @c_doc_end) AND
   (TRANSFER.EffectiveDate BETWEEN CONVERT(datetime, @d_date_start) AND DATEADD(day, 1, CONVERT(datetime, @d_date_end))) AND
   (TRANSFERDETAIL.FromSku = SKU.sku) AND
   (TRANSFERDETAIL.FromStorerkey = STORER.Storerkey)
END

GO