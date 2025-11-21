SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/    
/* Function: isp_GetIDInquiryImage                                            */    
/* Creation Date: 24-DEC-2015                                                 */    
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
/* PVCS Version: 1.0                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    

CREATE PROC [dbo].[isp_GetIDInquiryImage](  @c_ReceiptKey  NVARCHAR(10)
                                          , @c_ID          NVARCHAR(18)
                                          ) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_ImageURL01  NVARCHAR(150)   
         , @c_ImageURL02  NVARCHAR(150)
         , @c_ImageURL03  NVARCHAR(150)
         , @c_ImageURL04  NVARCHAR(150)
         , @c_ImageURL05  NVARCHAR(150)

         , @n_Cnt             INT
         , @c_ImageURL    NVARCHAR(100)
         , @c_SQL             NVARCHAR(100)


   SET @n_Cnt = 1

   CREATE TABLE #ID_IMAGES
         ( ReceiptKey      NVARCHAR(10)
         , ID              NVARCHAR(18)
         , ImageURL        NVARCHAR(150)
         )

   DECLARE CUR_PLIMG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  DISTINCT 
           PLIMG.ImageURL01
         , PLIMG.ImageURL02
         , PLIMG.ImageURL03
         , PLIMG.ImageURL04
         , PLIMG.ImageURL05
   FROM PALLETIMAGE PLIMG WITH (NOLOCK)
   WHERE ReceiptKey = @c_Receiptkey
   AND   ID         = @c_ID 

   OPEN CUR_PLIMG

   FETCH NEXT FROM CUR_PLIMG INTO  @c_ImageURL01  
                                 , @c_ImageURL02  
                                 , @c_ImageURL03  
                                 , @c_ImageURL04  
                                 , @c_ImageURL05  

 
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_Cnt = 1
      WHILE @n_Cnt <= 5
      BEGIN
         SET @c_ImageURL = ''
         SET @c_SQL = N'SET @c_ImageURL = @c_ImageURL0' + CONVERT(CHAR(1), @n_Cnt) 

         EXEC sp_ExecuteSql @c_SQL 
                          , N'@c_ImageURL      NVARCHAR(100) OUTPUT 
                             ,@c_ImageURL01    NVARCHAR(100) 
                             ,@c_ImageURL02    NVARCHAR(100) 
                             ,@c_ImageURL03    NVARCHAR(100) 
                             ,@c_ImageURL04    NVARCHAR(100) 
                             ,@c_ImageURL05    NVARCHAR(100)'
                          ,   @c_ImageURL      OUTPUT
                          ,   @c_ImageURL01
                          ,   @c_ImageURL02
                          ,   @c_ImageURL03
                          ,   @c_ImageURL04
                          ,   @c_ImageURL05

         IF ISNULL(@c_ImageURL,'') <> '' 
         BEGIN
            INSERT INTO #ID_IMAGES (ReceiptKey, ID, ImageURL)
            VALUES (@c_ReceiptKey, @c_ID, @c_ImageURL)
         END

         SET @n_Cnt = @n_Cnt + 1
      END
      FETCH NEXT FROM CUR_PLIMG INTO  @c_ImageURL01  
                                    , @c_ImageURL02  
                                    , @c_ImageURL03  
                                    , @c_ImageURL04  
                                    , @c_ImageURL05
   END
   CLOSE CUR_PLIMG
   DEALLOCATE CUR_PLIMG

   SELECT  DISTINCT 
           ReceiptKey       
         , ID               
         , ImageURL
         , '    ' rowfocusindicatorcol
   FROM #ID_IMAGES
END

GO