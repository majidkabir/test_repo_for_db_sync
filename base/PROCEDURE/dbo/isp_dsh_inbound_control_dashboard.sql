SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DSH_INBOUND_CONTROL_DASHBOARD                   */
/* Creation Date: 10-Apr-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22195 - RG SCE - Inbound door dashboard to logi report  */
/*                                                                      */
/* Usage: Call from Logi Report                                         */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 10-Apr-2023  WLChooi 1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_DSH_INBOUND_CONTROL_DASHBOARD]
(
   @c_Facility    NVARCHAR(5)
 , @d_BookingDate DATE
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   ;WITH CTE AS (
      SELECT Booking_In.BookingDate
           , Booking_In.Duration
           , Booking_In.BookingNo
           , Booking_In.ReceiptKey
           , Booking_In.POKey
           , Booking_In.UOMQty
           , Booking_In.NumberOfSKU
           , Booking_In.Qty
           , Booking_In.ReferenceNo
           , Booking_In.ContainerNo
           , Booking_In.Loc
           , ISNULL(Booking_In.ArrivedTime,'1900/01/01') AS ArrivedTime
           , ISNULL(Booking_In.SignInTime ,'1900/01/01') AS SignInTime 
           , ISNULL(Booking_In.UnloadTime ,'1900/01/01') AS UnloadTime 
           , ISNULL(Booking_In.DepartTime ,'1900/01/01') AS DepartTime 
           , Booking_In.Status
           , Booking_In.DriverName
           , CASE WHEN ISNULL(RECEIPT.StorerKey, '') <> '' THEN RECEIPT.StorerKey
                  WHEN ISNULL(PO.StorerKey, '') <> '' THEN PO.StorerKey END AS Storerkey
           , ROW_NUMBER() OVER (ORDER BY Booking_In.BookingDate) AS SeqNo
      FROM Booking_In (NOLOCK)
      LEFT JOIN RECEIPT (NOLOCK) ON (Booking_In.ReceiptKey = RECEIPT.ReceiptKey)
      LEFT JOIN PO (NOLOCK) ON (Booking_In.POKey = PO.POKey)
      WHERE Booking_In.Facility = @c_Facility AND DATEDIFF(DAY, Booking_In.BookingDate, @d_BookingDate) = 0
   )
   SELECT CTE.BookingDate
        , CTE.Duration
        , CTE.BookingNo
        , CTE.ReceiptKey
        , CTE.POKey
        , CTE.UOMQty
        , CTE.NumberOfSKU
        , CTE.Qty
        , CTE.ReferenceNo
        , CTE.ContainerNo
        , CTE.Loc
        , CTE.ArrivedTime
        , CTE.SignInTime 
        , CTE.UnloadTime 
        , CTE.DepartTime 
        , CL1.[Description] AS [Status]
        , CTE.DriverName
        , CTE.Storerkey
        , CTE.SeqNo
   FROM CTE
   OUTER APPLY ( SELECT TOP 1 CODELKUP.[Description]
                 FROM CODELKUP (NOLOCK) 
                 WHERE CODELKUP.LISTNAME = 'BKStatusI' AND CODELKUP.Code = CTE.[Status] 
                 AND (CODELKUP.Storerkey = CTE.StorerKey OR CODELKUP.Storerkey = '' OR CODELKUP.Storerkey IS NULL)
                 ORDER BY CASE WHEN CODELKUP.Storerkey = '' OR CODELKUP.Storerkey IS NULL THEN 2 ELSE 1 END) CL1
   ORDER BY CTE.BookingDate
END

GO