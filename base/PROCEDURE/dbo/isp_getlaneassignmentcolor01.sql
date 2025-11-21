SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetLaneAssignmentColor01                       */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Ver.  Author     Purposes                               */
/* 26-11-2019   1.0   WLChooi    Created (WMS-11096)                    */
/************************************************************************/
CREATE PROC [dbo].[isp_GetLaneAssignmentColor01]
   @c_Facility         NVARCHAR(5),
   @c_Loadkey          NVARCHAR(10),
   @c_Loc              NVARCHAR(10),
   @c_LocationCategory NVARCHAR(10),
   @n_BoxColor         INT           OUTPUT,
   @n_TextColor        INT           OUTPUT,
   @b_Success          INT           OUTPUT,  
   @n_Err              INT           OUTPUT, 
   @c_ErrMsg           NVARCHAR(255) OUTPUT  

AS
BEGIN
   DECLARE @n_Continue                    INT
         , @n_StartTCount                 INT   
         , @c_SPCode                      NVARCHAR(50)
         , @c_SQL                         NVARCHAR(MAX) 
         , @c_authority                   NVARCHAR(30)
         , @c_option1                     NVARCHAR(50)
         , @c_option2                     NVARCHAR(50)
         , @c_option3                     NVARCHAR(50)
         , @c_option4                     NVARCHAR(50)
         , @c_option5                     NVARCHAR(4000)
         , @c_ColorCFG                    NVARCHAR(4000)
         , @c_WithInventoryBoxColor       NVARCHAR(4000) 
         , @c_NoInventoryBoxColor         NVARCHAR(4000) 
         , @c_AvailableBoxColor           NVARCHAR(4000)  
         , @c_WithInventoryTextColor      NVARCHAR(4000)
         , @c_NoInventoryTextColor        NVARCHAR(4000)
         , @c_AvailableTextColor          NVARCHAR(4000) 

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  

   --Setup
   --'@c_WithInventoryBoxColor=8421504 @c_NoInventoryBoxColor=255 @c_AvailableBoxColor=65280 @c_WithInventoryTextColor=16777215 
   --@c_NoInventoryTextColor=16777215 @c_AvailableTextColor=0 '

   SELECT @c_ColorCFG  = LTRIM(RTRIM(CL.Notes2))
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'DBoardCFG'
   AND CL.Code = 'GetLaneAssignmentColor'
   AND CL.CODE2 = @c_Facility

   --BoxColor
   SELECT @c_WithInventoryBoxColor  = dbo.fnc_GetParamValueFromString('@c_WithInventoryBoxColor', @c_ColorCFG, @c_WithInventoryBoxColor) 
   SELECT @c_NoInventoryBoxColor    = dbo.fnc_GetParamValueFromString('@c_NoInventoryBoxColor', @c_ColorCFG, @c_NoInventoryBoxColor) 
   SELECT @c_AvailableBoxColor      = dbo.fnc_GetParamValueFromString('@c_AvailableBoxColor', @c_ColorCFG, @c_AvailableBoxColor) 

   --TextColor
   SELECT @c_WithInventoryTextColor = dbo.fnc_GetParamValueFromString('@c_WithInventoryTextColor', @c_ColorCFG, @c_WithInventoryTextColor) 
   SELECT @c_NoInventoryTextColor   = dbo.fnc_GetParamValueFromString('@c_NoInventoryTextColor', @c_ColorCFG, @c_NoInventoryTextColor) 
   SELECT @c_AvailableTextColor     = dbo.fnc_GetParamValueFromString('@c_AvailableTextColor', @c_ColorCFG, @c_AvailableTextColor)  

   IF @c_LocationCategory <> 'PACK&HOLD'
   BEGIN
      IF ISNULL(@c_Loadkey,'') = ''
      BEGIN
         SET @n_BoxColor  = CAST(@c_AvailableBoxColor AS INT)
         SET @n_TextColor = CAST(@c_AvailableTextColor AS INT) 
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE LOC = @c_Loc HAVING SUM(Qty) > 0)
         BEGIN
            SET @n_BoxColor  = CAST(@c_WithInventoryBoxColor AS INT)
            SET @n_TextColor = CAST(@c_WithInventoryTextColor AS INT)
         END
         ELSE
         BEGIN
            SET @n_BoxColor  = CAST(@c_NoInventoryBoxColor AS INT)
            SET @n_TextColor = CAST(@c_NoInventoryTextColor AS INT)
         END
      END
   END
   ELSE  --PACK&HOLD
   BEGIN
      IF EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE LOC = @c_Loc HAVING SUM(Qty) > 0)
      BEGIN
         SET @n_BoxColor  = CAST(@c_WithInventoryBoxColor AS INT)
         SET @n_TextColor = CAST(@c_WithInventoryTextColor AS INT)
      END
      ELSE
      BEGIN
         IF ISNULL(@c_Loadkey,'') = ''
         BEGIN
            SET @n_BoxColor  = CAST(@c_AvailableBoxColor AS INT)
            SET @n_TextColor = CAST(@c_AvailableTextColor AS INT)
         END
         ELSE
         BEGIN
            SET @n_BoxColor  = CAST(@c_NoInventoryBoxColor AS INT)
            SET @n_TextColor = CAST(@c_NoInventoryTextColor AS INT)
         END
      END
   END
   
QUIT:

   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_GetLaneAssignmentColor01'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END  
END

GO