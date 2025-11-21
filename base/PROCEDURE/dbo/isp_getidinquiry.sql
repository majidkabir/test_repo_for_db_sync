SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Function: isp_GetIDInquiry                                                 */    
/* Creation Date: 11-NOV-2014                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters: Search Parameters                                        */    
/*                                                                            */    
/* OUTPUT Parameters: Table                                                   */    
/*                                                                            */    
/* Return Status: NONE                                                        */    
/*                                                                            */    
/* Usage:                                                                     */    
/*                                                                            */    
/* Local Variables:                                                           */    
/*                                                                            */    
/* Called By: When Retrieve Records                                           */    
/*                                                                            */    
/* PVCS Version: 1.13                                                         */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    

CREATE PROC [dbo].[isp_GetIDInquiry](  @c_ReceiptKey  NVARCHAR(10)
                                    ,  @c_PermitNo    NVARCHAR(18) 
                                    ,  @c_LotNo       NVARCHAR(18) 
                                    ,  @c_ID          NVARCHAR(18)
                                    ,  @dt_FromDate   DATETIME  
                                    ,  @dt_ToDate     DATETIME 
                                   ) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_SQL       NVARCHAR(4000)
         , @c_Where     NVARCHAR(4000)
         , @c_OrderBy   NVARCHAR(500)

   SET @c_Where = ''

   IF @c_Receiptkey <> '' AND @c_Receiptkey IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.Receiptkey = N''' +  RTRIM(@c_Receiptkey) + ''''
   END

   IF @c_PermitNo <> '' AND @c_PermitNo IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.PermitNo = N''' +  RTRIM(@c_PermitNo) + ''''
   END

   IF @c_LotNo <> '' AND @c_LotNo IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.LotNo = N''' +  RTRIM(@c_LotNo) + ''''
   END

   IF @c_ID <> '' AND @c_ID IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.ID = N''' +  RTRIM(@c_ID) + ''''
   END

   IF @dt_FromDate IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.ReceiptDate >= N''' + RTRIM(CONVERT(NVARCHAR(20),@dt_FromDate, 106)) + ''''
   END

   IF @dt_ToDate IS NOT NULL 
   BEGIN
      SET @c_Where = @c_Where + ' AND PALLETIMAGE.ReceiptDate <= N''' + RTRIM(CONVERT(NVARCHAR(20),@dt_ToDate, 106)) + ''''
   END

   SET @c_OrderBy = ' ORDER BY PALLETIMAGE.ReceiptKey, PALLETIMAGE.ID'

   SET @c_SQL = N'SELECT DISTINCT'
              + '  PALLETIMAGE.ReceiptKey'  
              + ', PALLETIMAGE.PermitNo'            
              + ', PALLETIMAGE.ID'     
              + ', ''    '''           --rowfocusindicatorcol                 
              + ' FROM PALLETIMAGE WITH (NOLOCK) '
              + ' WHERE 1=1'

   SET @c_SQL = @c_SQL + @c_Where 

   SET @c_SQL = @c_SQL + @c_OrderBy

   EXEC (@c_SQL)
END

GO