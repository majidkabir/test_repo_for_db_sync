SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPKINS03                                          */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: WMS-19480 - PRSG - get sku pack instruction alert           */
/*                                                                      */
/* Called from: isp_PackGetInstruction_Wrapper                          */
/*              storerconfig: PackGetInstruction_SP                     */
/*                                                                      */
/* Exceed version: 7.0                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 05-APR-2022 1.0  NJOW       DEVOPS combine script                    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPKINS03]
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
                                    
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = '', @c_PackInstruction = ''
        
   IF ISNULL(@c_Sku,'') <> ''  --only get detail instruction for single order pack
   BEGIN   	   	 
   	  SELECT TOP 1 @c_PackInstruction = SUBSTRING(ISNULL(OD.Userdefine07,''),1,18) + SUBSTRING(ISNULL(OD.UserDefine08,''),1,14)
   	  FROM PICKHEADER PIH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PIH.Orderkey = O.Orderkey
   	  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	  AND PIH.Pickheaderkey = @c_Pickslipno
   	  AND O.SpecialHandling = 'P'
   	  AND ISNULL(OD.Userdefine06,'') <> ''
   	  AND OD.Storerkey = @c_Storerkey
   	  AND OD.Sku = @c_Sku
   	  
   	  IF ISNULL(@c_PackInstruction,'') <> ''
   	  BEGIN
   	  	 SET @c_PackInstruction = N'Personalization required. Check pick slip. 必查定制. 查查看Pick slip.'
   	     --SET @c_PackInstruction = 'Personalization required. ' + LTRIM(RTRIM(@c_PackInstruction)) + '. Continue pack?'
   	  END   	  
   END
END -- End Procedure

GO