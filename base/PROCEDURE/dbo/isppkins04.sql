SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPKINS04                                          */
/* Creation Date: 2023-05-05                                            */
/* Copyright      : MAERSK                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22508 - SG AESOP get header pack instruction            */
/*                                                                      */
/* Called By: isp_PackGetInstruction_Wrapper                            */
/*              storerconfig: PackGetInstruction_SP                     */
/*                                                                      */
/* Exceed version: 7.0                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 05-MAY-2023 1.0  NJOW       DEVOPS Combine SCript                    */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPKINS04]
   @c_Pickslipno       NVARCHAR(10),
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(50),  --if call from pack header sku no value(header instruction), if from packdetail sku have value(item instruction)
   @c_PackInstruction  NVARCHAR(500) OUTPUT,  
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_UserDefine02 NVARCHAR(20)
                                            
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = '', @c_PackInstruction = ''
        
   IF ISNULL(@c_Sku,'') = ''  --only get header instruction
   BEGIN   	
   	  SELECT @c_UserDefine02 = O.UserDefine02
      FROM PICKHEADER PH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      WHERE PH.Pickheaderkey = @c_Pickslipno
   	
   	  IF ISNULL(@c_UserDefine02,'') <> ''
   	  BEGIN
   	     SET @c_PackInstruction = 'VAS Code: ' + @c_UserDefine02
   	  END   	
   END   
END -- End Procedure


GO