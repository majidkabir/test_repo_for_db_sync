SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_DIDDecode01                                    */  
/* Creation Date: 13-Jul-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  336429-SG Melion GW - Dropid decode from packing module    */
/*                                                                      */  
/* Called By: Packing Module                                            */    
/*                                                                      */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROCEDURE [dbo].[isp_DIDDecode01]
      @c_DropID         NVARCHAR(50)  OUTPUT
   ,  @b_Success        INT           OUTPUT 
   ,  @n_Err            INT           OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_Continue INT,
            @n_First    INT,
            @n_Last     INT,
            @n_Start    INT,
            @c_Code     NVARCHAR(10) 

   SELECT @n_continue = 1, @n_Err = 0, @b_Success = 1, @c_ErrMsg = ''

   IF ISNULL(@c_DropId,'') = ''
      GOTO QUIT

   IF @n_continue IN (1,2)
   BEGIN
   	  SET @c_Code = '(21)'
   	  
   	  IF CHARINDEX(@c_Code, @c_DropId) > 0
   	  BEGIN
            SELECT @n_Start = CHARINDEX(@c_Code, @c_DropId)

            SELECT @n_First  = @n_Start + LEN(RTRIM(@c_Code))

            SELECT @n_Last = CHARINDEX(LEFT(@c_Code, 1), @c_DropId, @n_First) 
            IF @n_Last > 0
               SET @n_Last = @n_Last - 1
            ELSE
               SET @n_Last = LEN(RTRIM(@c_DropId))
            
            IF @n_First > 0 AND @n_Last > 0            
               SELECT @c_DropID = SUBSTRING(@c_DropId, @n_First, (@n_Last - @n_First) + 1)
   	  END 
   	  ELSE
   	  BEGIN
   	     SET @c_Code = '(25)'
   	  
   	     IF CHARINDEX(@c_Code, @c_DropId) > 0
   	     BEGIN
               SELECT @n_Start = CHARINDEX(@c_Code, @c_DropId)
         
               SELECT @n_First  = @n_Start + LEN(RTRIM(@c_Code))
         
               SELECT @n_Last = CHARINDEX(LEFT(@c_Code, 1), @c_DropId, @n_First) 
               IF @n_Last > 0
                  SET @n_Last = @n_Last - 1
               ELSE
                  SET @n_Last = LEN(RTRIM(@c_DropId))
               
               IF @n_First > 0 AND @n_Last > 0            
                  SELECT @c_DropID = SUBSTRING(@c_DropId, @n_First, (@n_Last - @n_First) + 1)
   	     END 
   	  END  	
   END
     
QUIT:

END -- End Procedure


GO