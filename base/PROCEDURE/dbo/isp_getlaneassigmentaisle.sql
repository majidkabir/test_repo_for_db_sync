SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetLaneAssigmentAisle                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
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
/* 14-01-2010   1.0   Shong      Create                                 */
/************************************************************************/
CREATE PROC [dbo].[isp_GetLaneAssigmentAisle]
   @c_Facility         NVARCHAR(5),
   @c_LocationCategory NVARCHAR(10),
   @n_LocLevel         INT,
   @c_Section          NVARCHAR(10) 
AS
BEGIN
    SET @c_Section = ISNULL(@c_Section,'')
    
	SELECT DISTINCT l.LocAisle 
	FROM LOC l WITH (NOLOCK)  
	WHERE l.Facility = @c_Facility    
	AND   l.LocationCategory = @c_LocationCategory
	AND   l.LocLevel = @n_LocLevel 
	AND   l.SectionKey = @c_Section
END

GO