SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPTL01                                           */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Get PTLKey by Remarks -- UNITY - SG                         */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 25-09-2014   ChewKP   1.1  Created.                                  */
/* 27-02-2017   TLTING   1.2  Variable Nvarchar                         */
/************************************************************************/

CREATE PROC [dbo].[ispPTL01]
   @c_IPAddress     NVARCHAR(40),      
   @c_LightLoc      NVARCHAR(20),      
   @c_QtyReturn     VARCHAR(5),       
   @n_PTLKey        INT           OUTPUT,              
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nLenReturn INT
           ,@cRemarks NVARCHAR(5) 
            
   SET @cRemarks = REPLACE(@c_QtyReturn,' ' , '' )
   SET @nLenReturn = LEN(@cRemarks)
   


   IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) 
                   WHERE IPAddress = @c_IPAddress          
                   AND   DevicePosition = @c_LightLoc           
                   AND   [Status] = '1'   
                   AND   Remarks = ''
                   AND   Loc = '' ) 
   BEGIN



      SELECT TOP 1 @n_PTLKey    = PTLKey            
      FROM PTLTran p WITH (NOLOCK)          
      WHERE p.IPAddress = @c_IPAddress          
      AND   p.DevicePosition = @c_LightLoc           
      AND   p.[Status] = '1' 
      AND   Remarks = ''  
     
            

   END
   ELSE 
   BEGIN

 
      -- MAX  5 Length -- 

      SELECT TOP 1 @n_PTLKey    = PTLKey            
      FROM PTLTran p WITH (NOLOCK)          
      WHERE p.IPAddress = @c_IPAddress          
      AND   p.DevicePosition = @c_LightLoc           
      AND   p.[Status] = '1'  
      AND  RIGHT(p.Remarks,@nLenReturn) = @cRemarks
   

      

   END
   
END

GO