SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function: fnc_CalculateCube                                          */
/* Creation Date: 29-May-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */  
/*                                                                      */
/* Purpose:  Calculate Cube (SOS#244886)                                */
/*                                                                      */
/* Called By:                                                           */  
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_CalculateCube] (@nLength Float, @nWidth Float, @nHeight Float, @cDimUOM NVARCHAR(30), @cVolUOM NVARCHAR(30), @cStorerkey NVARCHAR(15) )  
RETURNS Float
AS  
BEGIN  
   DECLARE @nCube Float
          ,@cSvalue NVARCHAR(10)
           
   IF ISNULL(@cStorerkey,'') <> '' AND ISNULL(@cDimUOM,'') = ''  
   BEGIN
      SELECT TOP 1 @cDimUOM = SValue
      FROM STORERCONFIG(NOLOCK)
      WHERE Configkey = 'SYSDIMUOM'
      AND Storerkey = @cStorerkey   	
   END

   IF ISNULL(@cStorerkey,'') <> '' AND ISNULL(@cVolUOM,'') = ''  
   BEGIN
      SELECT TOP 1 @cVolUOM = SValue
      FROM STORERCONFIG(NOLOCK)
      WHERE Configkey = 'SYSVOLUOM'
      AND Storerkey = @cStorerkey   	
   END
         
   IF ISNULL(@cDimUOM,'') = ''         
   BEGIN           
      SELECT @cDimUOM = NSQLValue
      FROM NSQLCONFIG(NOLOCK)
      WHERE Configkey = 'SYSDIMUOM'
   END
   
   IF ISNULL(@cVolUOM,'') = ''
   BEGIN                    
      SELECT @cVolUOM = NSQLValue
      FROM NSQLCONFIG(NOLOCK)
      WHERE Configkey = 'SYSVOLUOM'
   END
   
   --If no uom conversion setup and SKUAutoCalCube turned on then default convert CM dim to Cubic meter
   IF ISNULL(@cDimUOM,'') = '' AND ISNULL(@cVolUOM,'') = '' AND ISNULL(@cStorerkey,'') <> ''
   BEGIN
      SELECT TOP 1 @cSvalue = SValue
      FROM STORERCONFIG(NOLOCK)
      WHERE Configkey = 'SKUAutoCalCube'
      AND Storerkey = @cStorerkey
      
      IF @cSvalue = '1'
      BEGIN
         SET @cDimUOM = 'CM'
         SET @cVolUOM = 'M'
      END
   END
      
   IF ISNULL(@cDimUOM,'') <> '' AND ISNULL(@cVolUOM,'') <> ''
   BEGIN
   	  SELECT @nCube = CASE WHEN @cDimUOM = 'MM' AND @cVolUOM = 'CM' THEN
   	                       (@nLength / 10) * (@nWidth / 10) * (@nHeight / 10)   	                      
   	                       WHEN @cDimUOM = 'MM' AND @cVolUOM = 'IN' THEN
   	                       (@nLength / 25.4) * (@nWidth / 25.4) * (@nHeight / 25.4)   	                      
   	                       WHEN @cDimUOM = 'MM' AND @cVolUOM = 'FT' THEN
   	                       (@nLength / 304.8) * (@nWidth / 304.8) * (@nHeight / 304.8)   	                      
   	                       WHEN @cDimUOM = 'MM' AND @cVolUOM = 'M' THEN
   	                       (@nLength / 1000) * (@nWidth / 1000) * (@nHeight / 1000)   	                      
   	                       WHEN @cDimUOM = 'CM' AND @cVolUOM = 'MM' THEN
   	                       (@nLength * 10) * (@nWidth * 10) * (@nHeight * 10)   	                      
                           WHEN @cDimUOM = 'CM' AND @cVolUOM = 'IN' THEN
   	                       (@nLength / 2.54) * (@nWidth / 2.54) * (@nHeight / 2.54)   	                      
                           WHEN @cDimUOM = 'CM' AND @cVolUOM = 'FT' THEN
   	                       (@nLength / 30.48) * (@nWidth / 30.48) * (@nHeight / 30.48)   	                      
                           WHEN @cDimUOM = 'CM' AND @cVolUOM = 'M' THEN
   	                       (@nLength / 100) * (@nWidth / 100) * (@nHeight / 100)   	                      
   	                       WHEN @cDimUOM = 'IN' AND @cVolUOM = 'MM' THEN
   	                       (@nLength * 25.4) * (@nWidth * 25.4) * (@nHeight * 25.4)   	                      
                           WHEN @cDimUOM = 'IN' AND @cVolUOM = 'CM' THEN
   	                       (@nLength * 2.54) * (@nWidth * 2.54) * (@nHeight * 2.54)   	                      
                           WHEN @cDimUOM = 'IN' AND @cVolUOM = 'FT' THEN
   	                       (@nLength / 12) * (@nWidth / 12) * (@nHeight / 12)   	                      
                           WHEN @cDimUOM = 'IN' AND @cVolUOM = 'M' THEN
   	                       (@nLength / 39.37) * (@nWidth / 39.37) * (@nHeight / 39.37)   	                      
   	                       WHEN @cDimUOM = 'M' AND @cVolUOM = 'MM' THEN
   	                       (@nLength * 1000) * (@nWidth * 1000) * (@nHeight * 1000)   	                      
                           WHEN @cDimUOM = 'M' AND @cVolUOM = 'CM' THEN
   	                       (@nLength * 100) * (@nWidth * 100) * (@nHeight * 100)   	                      
                           WHEN @cDimUOM = 'M' AND @cVolUOM = 'IN' THEN
   	                       (@nLength * 39.37) * (@nWidth * 39.37) * (@nHeight * 39.37)   	                      
                           WHEN @cDimUOM = 'M' AND @cVolUOM = 'FT' THEN
   	                       (@nLength * 3.281) * (@nWidth * 3.281) * (@nHeight * 3.281)   	                      
   	                       ELSE @nLength * @nWidth * @nHeight
   	                  END
   END
   ELSE
   BEGIN
   	  SELECT @nCube = @nLength * @nWidth * @nHeight
   END 
                  	    
   RETURN ISNULL(@nCube,0)
END

GO