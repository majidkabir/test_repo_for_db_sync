SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: fnc_Get_WMReportDetail                                      */
/* Creation Date: 14-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-183:List of Labels, Document Print and Reports to be   */
/*          considered & DB procedute Details for the same              */
/*        :                                                             */
/*                                                                      */
/* Called By:  lsp_WM_Get_ModuleReport                                  */
/*          :  lsp_WM_Print_Report                                      */
/*          :                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE FUNCTION [WM].[fnc_Get_WMReportDetail] 
  ( 
      @c_ReportID       NVARCHAR(10)
   ,  @c_Storerkey      NVARCHAR(15)
   ,  @c_Facility       NVARCHAR(5)
   ,  @c_UserName       NVARCHAR(128)
   ,  @c_ComputerName   NVARCHAR(30)
   ,  @c_ReturnAll      CHAR(1) = 'N'
  )
RETURNS @t_WMREPORTDETAIL TABLE   
(   RowID    BIGINT  PRIMARY KEY
)     
AS
BEGIN
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   
   DECLARE @c_MaxStorerkey    NVARCHAR(15)
         , @c_MaxFacility     NVARCHAR(5)
         , @c_MaxUserName     NVARCHAR(30)
         , @c_MaxComputerName NVARCHAR(30)

         , @CUR_MATCH         CURSOR
   
   -- Search BY Storerkey & facility
   INSERT INTO @t_WMREPORTDETAIL (RowID)
   SELECT WMRD.RowID
   FROM dbo.WMREPORTDETAIL WMRD WITH (NOLOCK)
   WHERE WMRD.ReportID = @c_ReportID
   AND   WMRD.Storerkey= @c_Storerkey
   AND   WMRD.Facility = @c_Facility

   -- Search BY Storerkey  
   IF NOT EXISTS (SELECT 1
                  FROM @t_WMREPORTDETAIL
                 )
   BEGIN
      INSERT INTO @t_WMREPORTDETAIL (RowID)
      SELECT WMRD.RowID
      FROM dbo.WMREPORTDETAIL WMRD WITH (NOLOCK)
      WHERE WMRD.ReportID = @c_ReportID
      AND   WMRD.Storerkey= @c_Storerkey
      AND   WMRD.Facility = ''
   END

   -- Search BY Facility  
   IF NOT EXISTS (SELECT 1
                  FROM @t_WMREPORTDETAIL
                  )
   BEGIN
      INSERT INTO @t_WMREPORTDETAIL (RowID)
      SELECT WMRD.RowID
      FROM dbo.WMREPORTDETAIL WMRD WITH (NOLOCK)
      WHERE WMRD.ReportID = @c_ReportID
      AND   WMRD.Storerkey= ''
      AND   WMRD.Facility = @c_Facility
   END

   --Search BY All 
   IF @c_ReturnAll = 'Y'
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM @t_WMREPORTDETAIL
                    )
      BEGIN
         INSERT INTO @t_WMREPORTDETAIL (RowID)
         SELECT WMRD.RowID
         FROM dbo.WMREPORTDETAIL WMRD WITH (NOLOCK)
         WHERE WMRD.ReportID = @c_ReportID
      END
   END

   RETURN
END 

GO