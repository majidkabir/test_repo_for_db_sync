SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetLaneAssigmentDashboard                      */
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
/* 17-03-2010   1.1   ChewKP     Temp Solutions for do not display      */
/*                               Loadplan without header (ChewKP01)     */  
/* 10-11-2011   1.2   NJOW01     229328 - Cater for mbol                */
/* 19-11-2019   1.3   WLChooi    WMS-11096 - Add total available loc    */
/*                               left per aisle and enable customization*/
/*                               of BoxColor and TextColor (WL01)       */            
/************************************************************************/
CREATE PROC [dbo].[isp_GetLaneAssigmentDashboard]
   @c_Facility         NVARCHAR(5),
   @c_LocationCategory NVARCHAR(10),
   @n_LocLevel         INT,
   @c_Section          NVARCHAR(10), 
   @c_Aisle            NVARCHAR(10) 
AS
BEGIN
   --WL01 Start
   DECLARE @n_TotalLoc           INT = 0
         , @n_TotalLocAvailable  INT = 0 
         , @c_SPCode             NVARCHAR(50) = ''
         , @c_SQL                NVARCHAR(MAX) = ''
         , @n_BoxColor           INT = 0
         , @n_TextColor          INT = 0
         , @c_Loc                NVARCHAR(10) = ''
         , @c_Loadkey            NVARCHAR(10) = ''
         , @b_Success            INT = 1
         , @n_Err                INT = 0
         , @c_ErrMsg             NVARCHAR(255) = ''

   --WL01 End

   SET @c_Section = ISNULL(@c_Section,'')
    
	SELECT L.LocAisle, L.loc AS Loc, MIN(RTRIM(ISNULL(LPLD.LoadKey,''))+RTRIM(ISNULL(LPLD.Mbolkey,''))) AS LoadKey, 0 AS BoxColor, 0 AS TextColor --WL01
   INTO #Temp_GetLaneAssignmetDashBoard         --WL01
   FROM   LOC l WITH (NOLOCK)
          LEFT OUTER JOIN LoadPlanLaneDetail LPLD WITH (NOLOCK)
               ON  LPLD.LOC = L.LOC AND
                   LPLD.STATUS<>'9'
                   AND (EXISTS (SELECT 1 FROM LoadPlan lp (nolock) Where lpld.loadkey = lp.loadkey) OR ISNULL(LPLD.Loadkey,'')='')
                   AND (EXISTS (SELECT 1 FROM Mbol mb (nolock) Where lpld.mbolkey = mb.mbolkey) OR ISNULL(LPLD.Mbolkey,'')='')
   WHERE  L.Facility = @c_Facility AND
          L.LocationCategory = @c_LocationCategory AND
          L.LocLevel = @n_LocLevel AND
          L.SectionKey = @c_Section AND
          L.LocAisle = @c_Aisle
   GROUP BY
          L.LocAisle
         ,L.loc
   
   --WL01 Start
   SELECT @n_TotalLoc          = COUNT(1) FROM #Temp_GetLaneAssignmetDashBoard
   SELECT @n_TotalLocAvailable = COUNT(1) FROM #Temp_GetLaneAssignmetDashBoard WHERE LoadKey = ''

   SELECT @c_SPCode = LTRIM(RTRIM(CL.Long))
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'DBoardCFG'
   AND CL.Code = 'GetLaneAssignmentColor'
   AND CL.CODE2 = @c_Facility

   IF ISNULL(@c_SPCode,'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
      BEGIN        
         GOTO QUIT_SP  
      END        
      
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Facility = @c_FacilityP, @c_Loadkey = @c_LoadkeyP, @c_Loc = @c_LocP, @c_LocationCategory = @c_LocationCategoryP,
                   @n_BoxColor = @n_BoxColorP OUTPUT, @n_TextColor = @n_TextColorP OUTPUT,
                   @b_Success = @b_SuccessP OUTPUT, @n_Err = @n_ErrP OUTPUT, @c_ErrMsg = @c_ErrMsgP OUTPUT '  

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loc, Loadkey
      FROM #Temp_GetLaneAssignmetDashBoard
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_Loc, @c_Loadkey 
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC sp_executesql @c_SQL   
          ,N'@c_FacilityP NVARCHAR(5), @c_LoadkeyP NVARCHAR(10), 
            @c_LocP NVARCHAR(10), @c_LocationCategoryP NVARCHAR(10), @n_BoxColorP INT OUTPUT, @n_TextColorP INT OUTPUT,
            @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(255) OUTPUT '   
          ,@c_Facility
          ,@c_Loadkey                  
          ,@c_Loc                 
          ,@c_LocationCategory 
          ,@n_BoxColor      OUTPUT                    
          ,@n_TextColor     OUTPUT               
          ,@b_Success       OUTPUT  
          ,@n_Err           OUTPUT  
          ,@c_ErrMsg        OUTPUT           

         IF @b_Success <> 1
         BEGIN
            GOTO QUIT_SP
         END

         UPDATE #Temp_GetLaneAssignmetDashBoard
         SET BoxColor = @n_BoxColor, TextColor = @n_TextColor
         WHERE Loc = @c_Loc AND Loadkey = @c_Loadkey
   
         FETCH NEXT FROM CUR_LOOP INTO @c_Loc, @c_Loadkey 
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP       
   END
   ELSE
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loc, Loadkey
      FROM #Temp_GetLaneAssignmetDashBoard
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_Loc, @c_Loadkey 
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNULL(@c_Loadkey,'') = ''
         BEGIN
            SET @n_BoxColor = 65280 --Green
            SET @n_TextColor = 0    
         END
         ELSE
         BEGIN
            SET @n_BoxColor = 255       --Red
            SET @n_TextColor = 16777215 --White
         END

         UPDATE #Temp_GetLaneAssignmetDashBoard
         SET BoxColor = @n_BoxColor, TextColor = @n_TextColor
         WHERE Loc = @c_Loc AND Loadkey = @c_Loadkey
   
         FETCH NEXT FROM CUR_LOOP INTO @c_Loc, @c_Loadkey 
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP    

   END

   SELECT *, @n_TotalLoc AS TotalLoc, @n_TotalLocAvailable AS TotalLocAvailable FROM #Temp_GetLaneAssignmetDashBoard

QUIT_SP:
   IF OBJECT_ID('tempdb..#Temp_GetLaneAssignmetDashBoard') IS NOT NULL
      DROP TABLE #Temp_GetLaneAssignmetDashBoard
   --WL01 End
END

GO