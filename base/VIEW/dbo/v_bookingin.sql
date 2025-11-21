SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: V_BookingIn                                        */
/* Creation Date: 23-Aug-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose:  For reporting purposes                                     */
/*                                                                      */
/* Called By: E-WMS                                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE   VIEW [dbo].[V_BookingIn]
AS
   SELECT DISTINCT
      CONVERT(NVARCHAR(10), BI.BookingNo) [BookingNo],
      (CASE WHEN ISNULL(RTRIM(SC.SValue),0) = 1 THEN PO.SellersReference ELSE PO.SellerName END) AS [SupplierCode],
      PO.POKey [POKey],
      PO.ExternPOKey [ExternPOKey],
      BI.BookingDate [BookingDate],
      BI.EndTime [EndTime],
      BI.Facility [Facility],
      BI.Loc [Door],
      BI.Type [TruckType],
      BI.Remark [Remark]
   FROM PO WITH (NOLOCK)
   LEFT OUTER JOIN StorerConfig SC (NOLOCK)
      ON PO.StorerKey = SC.StorerKey
      AND SC.ConfigKey = 'POSellerInRefField'
   JOIN Booking_In BI WITH (NOLOCK)
      ON BI.POKey = PO.POKey
   WHERE bi.EndTime > bi.BookingDate   -- Commented in UAT
   AND PO.[Status] <> '9'              -- Commented in UAT


GO