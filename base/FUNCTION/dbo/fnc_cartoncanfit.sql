SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_CartonCanFit                                           */
/* Creation Date: 28-May-2024                                           */
/* Copyright: Maersk Logistics                                          */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: UWP-18747 - Levis US MPOC and Cartonization                 */
/*        :                                                             */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-May-2024 Shong    1.1   Create                                    */
/************************************************************************/
CREATE   FUNCTION fnc_CartonCanFit 
(
   @n_SKULength     float = 0,
   @n_SKUWidth      float = 0,
   @n_SKUHeight     float = 0,
   @n_CartonLength  float = 0,
   @n_CartonWidth   float = 0,
   @n_CartonHeight  float = 0   
   ) 
RETURNS BIT 
AS
BEGIN
	DECLARE @b_CanFit BIT = 0

   IF @n_SKULength <= @n_CartonLength AND
      @n_SKUWidth <= @n_CartonWidth AND
      @n_SKUHeight <= @n_CartonHeight
   BEGIN
      SET @b_CanFit = 1
   END 
   ELSE IF @n_SKUWidth <= @n_CartonLength AND
         @n_SKULength <= @n_CartonWidth AND
         @n_SKUHeight <= @n_CartonHeight 
   BEGIN
      SET @b_CanFit = 1
   END
   ELSE IF @n_SKUHeight <= @n_CartonLength AND
      @n_SKULength <= @n_CartonWidth AND
      @n_SKUWidth <= @n_CartonHeight
   BEGIN
      SET @b_CanFit = 1
   END
   ELSE IF @n_SKUHeight <= @n_CartonLength AND
      @n_SKUWidth <= @n_CartonWidth AND
      @n_SKULength <= @n_CartonHeight
   BEGIN
      SET @b_CanFit = 1
   END
   ELSE IF @n_SKUWidth <= @n_CartonLength AND
      @n_SKUHeight <= @n_CartonWidth AND
      @n_SKULength <= @n_CartonHeight  
   BEGIN
      SET @b_CanFit = 1
   END ELSE IF @n_SKULength <= @n_CartonLength AND
      @n_SKUHeight <= @n_CartonWidth AND
      @n_SKUWidth <= @n_CartonHeight
   BEGIN
      SET @b_CanFit = 1
   END

	-- Return the result of the function
	RETURN @b_CanFit

END

GO