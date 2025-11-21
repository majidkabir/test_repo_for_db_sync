SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : fnc_get_lpVolWgtUsed                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Return Loadplan Volume and Weight Used                      */
/*                                                                      */
/*                                                                      */
/* Usage: SELECT * from dbo.fnc_get_lpVolWgtUsed (Loadkey)              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2014-04-21   1.0  TLTING     Created                                 */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_get_lpVolWgtUsed]
(
    @c_loadkey   NVARCHAR(10),
    @n_fieldtype INT 
)
RETURNS TABLE
AS
RETURN (
    WITH Result1 (VVol_Wgt, Cube_Wgt, Return_Cube_Wgt) AS (
                SELECT SUM(ISNULL(ids_vehicle.Volume, 0)), ISNULL(loadplan.[Cube],0), ISNULL(loadplan.Return_Cube, 0)
                FROM loadplan (NOLOCK)
                JOIN ids_lp_vehicle WITH (NOLOCK) ON loadplan.loadkey = ids_lp_vehicle.loadkey
                JOIN ids_vehicle WITH (NOLOCK) ON ids_lp_vehicle.vehiclenumber = ids_vehicle.vehiclenumber
                WHERE loadplan.loadkey = @c_loadkey
                AND @n_fieldtype = 1
                GROUP BY ISNULL(loadplan.[Cube],0), ISNULL(loadplan.Return_Cube, 0)
                UNION ALL
                SELECT SUM(ISNULL(ids_vehicle.Weight, 0)), ISNULL(loadplan.Weight,0), ISNULL(loadplan.Return_Weight, 0)
                FROM loadplan (NOLOCK)
                JOIN ids_lp_vehicle WITH (NOLOCK) ON loadplan.loadkey = ids_lp_vehicle.loadkey
                JOIN ids_vehicle WITH (NOLOCK) ON ids_lp_vehicle.vehiclenumber = ids_vehicle.vehiclenumber
                WHERE loadplan.loadkey = @c_loadkey
                AND @n_fieldtype = 2
                GROUP BY ISNULL(loadplan.Weight,0), ISNULL(loadplan.Return_Weight, 0)                
    )
    SELECT VVol_Wgt, Cube_Wgt, Return_Cube_Wgt
    FROM Result1
  )

GO