SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Booking_GetSupplierDelvDate                    */
/* Creation Date: 01 Jan 2012                                           */
/* Copyright: LFL                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: EWMS                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 01-Jan-2012  TKLIM     1.0   Initial                                 */
/************************************************************************/
  
  
CREATE PROCEDURE [dbo].[isp_Booking_GetSupplierDelvDate] (                       
   @cSupplierCode NVARCHAR(15)                      
  ,@cExterPOKey   NVARCHAR(20) )                      
AS                      
BEGIN                      
    -- SET NOCOUNT ON added to prevent extra result sets from                      
    SET NOCOUNT ON;                      
                       
    SELECT DISTINCT     
        (CASE WHEN ISNULL(RTRIM(SC.SValue),0) = 1 THEN PO.SellersReference ELSE PO.SellerName END) AS SupplierCode,                       
        PO.POKey,                       
        PO.ExternPOKey,                       
        CONVERT(VARCHAR(10), bi.BookingNo) AS BookingNo ,                       
        --CASE WHEN Datepart(hour, bi.BookingDate) = 0                       
        CASE WHEN bi.EndTime = bi.BookingDate            
            THEN CONVERT(VARCHAR(10), bi.BookingNo) + ' - ' + LEFT( CONVERT(VARCHAR(20), bi.BookingDate, 109), 11)             
            ELSE CONVERT(VARCHAR(10), bi.BookingNo) + ' - ' + LEFT( CONVERT(VARCHAR(20), bi.BookingDate, 109), 11) + ' ( ' + SubString(CONVERT(VARCHAR(5), bi.BookingDate, 108), 1, 5) + ' )'                          
        END AS Booked                
    FROM PO WITH (NOLOCK)                      
    LEFT OUTER JOIN StorerConfig SC  WITH (NOLOCK)      
        ON PO.StorerKey = SC.StorerKey 
        and SC.ConfigKey = 'POSellerInRefField'      
    JOIN Booking_In BI WITH (NOLOCK) 
        ON BI.POKey = PO.POKey           
    WHERE (CASE WHEN ISNULL(RTRIM(SC.SValue),0) = 1 THEN PO.SellersReference ELSE PO.SellerName END) = RTRIM(@cSupplierCode)                    
        AND   ExternPOKey = @cExterPOKey    
        -- AND   po.[Status] <> '9'                       
                       
END 

GO