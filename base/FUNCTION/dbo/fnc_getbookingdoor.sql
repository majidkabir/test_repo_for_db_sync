SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_GetBookingDoor                                         */
/* Creation Date: 01-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-917 - WMS Door Booking Enhancement                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetBookingDoor] 
         (
            @c_Facility       NVARCHAR(5)
          , @c_Loc            NVARCHAR(10) 
          , @c_ToLoc          NVARCHAR(10) = ''
          , @c_Loc2           NVARCHAR(10) = ''  
          , @c_InOut          CHAR(1) = 'I' )  
              
RETURNS @tBookDoor TABLE       
(     Loc   NVARCHAR(10) NOT NULL 
)      
AS      
BEGIN
   DECLARE @c_LocCategory  NVARCHAR(10)
   
   IF ISNULL(@c_Loc,'') = '' 
   BEGIN
      RETURN
   END

   IF ISNULL(@c_ToLoc,'') = ''
   BEGIN 
      SET @c_ToLoc = @c_Loc
   END  

   IF ISNULL(@c_Loc2,'') <> ''
   BEGIN 
      INSERT INTO @tBookDoor ( Loc )
      VALUES (@c_Loc2)
   END

   IF @c_InOut = 'I'
   BEGIN
      SET @c_LocCategory = 'BayIn'

   END
   ELSE
   BEGIN
      SET @c_LocCategory = 'BayOut'
   END

 
   INSERT INTO @tBookDoor ( Loc )
   SELECT LOC                  
   FROM LOC WITH (NOLOCK)   
   LEFT JOIN CODELKUP WITH (NOLOCK) ON LOC.LOC = CODELKUP.Long 
                                    AND LOC.Facility = CODELKUP.Short 
                                    AND CODELKUP.Listname = 'USREXCLBAY' 
                                    AND CODELKUP.UDF01 = SUSER_SNAME() 
   WHERE LocationCategory IN (@c_LocCategory,'Bay') 
   AND LOC.Facility = @c_facility 
   AND LOC.Loc BETWEEN @c_Loc AND @c_ToLoc
   AND CODELKUP.Code IS NULL 
   GROUP BY Logicallocation, Loc 
   ORDER BY logicallocation, Loc
    

   RETURN
END -- procedure

GO