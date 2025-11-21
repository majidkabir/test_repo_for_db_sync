SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Get_Order_PI_Encrypted                         */
/* Creation Date: 31-Mar-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Encrypt Personal Information for Order                      */
/*                                                                      */
/* Called By: Interface                                                 */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Get_Order_PI_Encrypted]  
   @c_OrderKey NVARCHAR(10), 
   @b_success  INT = 1 OUTPUT, 
   @n_ErrNo    INT = 0 OUTPUT,
   @c_ErrMsg   NVARCHAR(250) = '' OUTPUT 
   
AS    
BEGIN



   BEGIN TRY
      OPEN SYMMETRIC KEY Smt_Key_Orders_PI  
      DECRYPTION BY CERTIFICATE Cert_Orders_PI;
   END TRY
   
   BEGIN CATCH
      SELECT     
        @n_ErrNo  = ERROR_NUMBER()  
       ,@c_ErrMsg = ERROR_MESSAGE() 
       ,@b_success = 0 
       
       GOTO QUICK_SP
   END CATCH
   
   
 

   SELECT *  FROM fnc_GetDecryptedOrderPI(@c_OrderKey);



   QUICK_SP:
         
         
END


GO