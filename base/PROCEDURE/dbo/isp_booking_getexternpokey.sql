SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Booking_GetExternPOKey                         */
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
  
CREATE PROCEDURE [dbo].[isp_Booking_GetExternPOKey] (         
    @cSupplierCode NVARCHAR(15) )        
AS        
BEGIN        
    -- SET NOCOUNT ON added to prevent extra result sets from        
    -- interfering with SELECT statements.        
    SET NOCOUNT ON;        
       
    IF ISNULL(RTRIM(@cSupplierCode),'') = ''    
    BEGIN    
        GOTO QUIT    
    END    
       
       
    SELECT '(select)'     
    UNION ALL        
    SELECT DISTINCT PO.ExternPOKey    
    FROM PO PO WITH (NOLOCK)
    LEFT OUTER JOIN StorerConfig SC WITH (NOLOCK)  
        ON PO.StorerKey = SC.StorerKey 
        AND SC.ConfigKey = 'POSellerInRefField'    
    JOIN Booking_In BI WITH (NOLOCK) 
        ON BI.POKey = PO.POKey         
    WHERE (CASE WHEN ISNULL(RTRIM(SC.SValue),0) = 1 THEN PO.SellersReference ELSE PO.SellerName END) = RTRIM(@cSupplierCode)    
        AND   PO.ExternPOKey > ''         
        --AND   PO.[Status] <> '9'         
       
       
    QUIT:    
       
END 

GO