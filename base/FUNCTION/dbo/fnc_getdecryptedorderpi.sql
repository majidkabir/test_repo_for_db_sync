SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store Procedure: fnc_GetDecryptedOrderPI                                */
/* Creation Date: 27-Mar-2020                                              */
/* Copyright: LF                                                           */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: Decrypt Orders_PI_Encrypted data                               */
/*                                                                         */
/* Called By: sp report, label, and outbound interface to courier and TMS  */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 09-Oct-2020  TLTING01  1.1   Convert NVARCAR bug                        */
/* 08-Mar-2021  SHONG     1.2   Adding ISNULL default to Blank             */
/* 08-Mar-2021  TLTING02  1.3   field length extend                        */
/***************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetDecryptedOrderPI]   
(  
 @c_OrderKey NVARCHAR(10)  
)  
RETURNS   
@t_Orders_PI_Decrypted TABLE   
(  
 OrderKey NVARCHAR(10),  
   C_Contact1 [NVARCHAR](200),  
   C_Contact2 [NVARCHAR](200),  
   C_Company  [NVARCHAR](100),  --TLTING02
   C_Address1 [NVARCHAR](45),  
   C_Address2 [NVARCHAR](45),  
   C_Address3 [NVARCHAR](45),  
   C_Address4 [NVARCHAR](45),  
   C_City     [NVARCHAR](45),  
   C_State    [NVARCHAR](45),  
   C_Zip      [NVARCHAR](18),  
   C_Phone1   [NVARCHAR](18),  
   C_Phone2   [NVARCHAR](18),  
   C_Fax1     [NVARCHAR](18),  
   C_Fax2     [NVARCHAR](18),  
   B_Contact1 [NVARCHAR](200),  
   B_Contact2 [NVARCHAR](200),  
   B_Company  [NVARCHAR](100),  --TLTING02
   B_Address1 [NVARCHAR](45),  
   B_Address2 [NVARCHAR](45),  
   B_Address3 [NVARCHAR](45),  
   B_Address4 [NVARCHAR](45),  
   B_City     [NVARCHAR](45),  
   B_State    [NVARCHAR](45),  
   B_Zip      [NVARCHAR](18),  
   B_Phone1   [NVARCHAR](18),  
   B_Phone2   [NVARCHAR](18),  
   B_Fax1     [NVARCHAR](18),  
   B_Fax2     [NVARCHAR](18),  
   M_Contact1 [NVARCHAR](200),  
   M_Contact2 [NVARCHAR](200),  
   M_Company  [NVARCHAR](100),  --TLTING02
   M_Address1 [NVARCHAR](45),  
   M_Address2 [NVARCHAR](45),  
   M_Address3 [NVARCHAR](45),  
   M_Address4 [NVARCHAR](45),  
   M_City     [NVARCHAR](45),  
   M_State    [NVARCHAR](45),  
   M_Zip      [NVARCHAR](18),  
   M_Phone1   [NVARCHAR](18),  
   M_Phone2   [NVARCHAR](18),  
   M_Fax1     [NVARCHAR](18),  
   M_Fax2     [NVARCHAR](18)       
)  
AS  
BEGIN  
   INSERT INTO @t_Orders_PI_Decrypted  
   (  
      OrderKey,  
      C_Contact1,  
      C_Contact2,  
      C_Company,  
      C_Address1,  
      C_Address2,  
      C_Address3,  
      C_Address4,  
      C_City,  
      C_State,  
      C_Zip,  
      C_Phone1,  
      C_Phone2,  
      C_Fax1,  
      C_Fax2,                 
      B_Contact1,  
      B_Contact2,  
      B_Company,  
      B_Address1,  
      B_Address2,  
      B_Address3,  
      B_Address4,  
      B_City,  
      B_State,  
      B_Zip,  
      B_Phone1,  
      B_Phone2,  
      B_Fax1,  
      B_Fax2,  
      M_Contact1,  
      M_Contact2,  
      M_Company,  
      M_Address1,  
      M_Address2,  
      M_Address3,  
      M_Address4,  
      M_City,  
      M_State,  
      M_Zip,  
      M_Phone1,  
      M_Phone2,  
      M_Fax1,  
      M_Fax2          
   )     
   SELECT  
      OrderKey,  
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(C_Contact1)),''),   -- TLTING01
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(C_Contact2)),''),  
      ISNULL(CONVERT([NVARCHAR](100),   DECRYPTBYKEY(C_Company)),''),    --tlting02
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_Address1)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_Address2)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_Address3)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_Address4)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_City)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(C_State)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(C_Zip)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(C_Phone1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(C_Phone2)),''),   
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(C_Fax1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(C_Fax2)),''),  
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(B_Contact1)),''),   
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(B_Contact2)),''),  
      ISNULL(CONVERT([NVARCHAR](100),   DECRYPTBYKEY(B_Company)),''),   --tlting02
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_Address1)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_Address2)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_Address3)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_Address4)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_City)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(B_State)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(B_Zip)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(B_Phone1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(B_Phone2)),''),   
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(B_Fax1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(B_Fax2)),''),   
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(M_Contact1)),''),   
      ISNULL(CONVERT([NVARCHAR](200),   DECRYPTBYKEY(M_Contact2)),''),  
      ISNULL(CONVERT([NVARCHAR](100),   DECRYPTBYKEY(M_Company)),''),  --tlting02
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_Address1)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_Address2)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_Address3)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_Address4)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_City)),''),  
      ISNULL(CONVERT([NVARCHAR](45),    DECRYPTBYKEY(M_State)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(M_Zip)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(M_Phone1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(M_Phone2)),''),   
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(M_Fax1)),''),  
      ISNULL(CONVERT([NVARCHAR](18),    DECRYPTBYKEY(M_Fax2)),'')                   
    FROM Orders_PI_Encrypted O WITH (NOLOCK)  
    WHERE O.OrderKey = @c_OrderKey;     
   
   QUICK_FN:  
 RETURN   
END  

GO