SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_ValidateAssignLane                              */  
/* Creation Date: 25-JAN-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#265537 - VFCDC-Assign Sort and Dispatch Lane             */  
/*                                                                       */  
/* Called By: Call when Exit from Lane Assignment Screen                 */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  

CREATE PROC [dbo].[isp_ValidateAssignLane]
      @c_Loadkey  NVARCHAR(10)
   ,  @c_MBOLKey  NVARCHAR(10)
   ,  @b_Success  INT            OUTPUT
   ,  @n_Err      INT            OUTPUT
   ,  @c_ErrMsg   VARCHAR(255)   OUTPUT         
AS  
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @n_Continue        INT

   DECLARE @c_ExecStatement   NVARCHAR(4000)
         , @c_ExecArguements  NVARCHAR(4000)

   SET @c_Loadkey       = ISNULL(RTRIM(@c_Loadkey),'')
   SET @c_MBOLKey       = ISNULL(RTRIM(@c_MBOLKey),'')
   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_ErrMsg        = ''
     
   SET @n_Continue      = 1
    
   SET @c_ExecStatement = ''
   SET @c_ExecArguements= ''

   CREATE TABLE #TMP_ORD
   (  MBOLKey        NVARCHAR(10) NOT NULL DEFAULT('')
   ,  Loadkey        NVARCHAR(10) NOT NULL DEFAULT('')
   ,  Orderkey       NVARCHAR(10) NOT NULL DEFAULT('')
   ,  Door           NVARCHAR(10) NULL )

   

   IF ISNULL(RTRIM(@c_MBOLKey),'') = ''  
   BEGIN
      INSERT INTO #TMP_ORD ( Loadkey, Orderkey, Door )
      SELECT LOADPLANDETAIL.Loadkey
            ,LOADPLANDETAIL.Orderkey
            ,ORDERS.Door
      FROM LOADPLANDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ORD ( MBOLKey, Orderkey, Door )
      SELECT MBOLDETAIL.MBOLKey
            ,MBOLDETAIL.Orderkey
            ,ORDERS.Door
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE MBOLDETAIL.MBOLKey = @c_MBOLkey
   END

   IF NOT EXISTS (SELECT 1
                  FROM #TMP_ORD TMP  
                  JOIN ORDERS WITH (NOLOCK) ON (TMP.Orderkey = ORDERS.Orderkey)
                  JOIN STORERCONFIG WITH (NOLOCK) ON (ORDERS.Storerkey = STORERCONFIG.Storerkey)
                  WHERE STORERCONFIG.Configkey  = 'VFLaneControl'
                  AND STORERCONFIG.SValue = '1')
   BEGIN
      GOTO QUIT
   END
 
   IF NOT EXISTS (SELECT 1
                  FROM #TMP_ORD TMP
                  JOIN LOADPLANLANEDETAIL WITH (NOLOCK) ON (TMP.Loadkey = LOADPLANLANEDETAIL.Loadkey)
                                                        AND(TMP.MBOLkey = LOADPLANLANEDETAIL.MBOLkey))
   BEGIN
      GOTO QUIT 
   END


   IF EXISTS (SELECT 1
              FROM #TMP_ORD TMP
              WHERE (TMP.Door = '' OR TMP.Door IS NULL))  
--              LEFT JOIN LOADPLANLANEDETAIL WITH (NOLOCK) ON (TMP.MBOLKey = LOADPLANLANEDETAIL.MBOLKey)
--                                                         AND(TMP.Loadkey = LOADPLANLANEDETAIL.Loadkey) 
--                                                         AND(TMP.ExternOrderkey = LOADPLANLANEDETAIL.ExternOrderkey)
--                                                         AND(TMP.Consigneekey = LOADPLANLANEDETAIL.Consigneekey)
--                                                         AND(TMP.Door = LOADPLANLANEDETAIL.Loc)
--                                                         AND(LOADPLANLANEDETAIL.LocationCategory = 'PROC')
--              WHERE LOADPLANLANEDETAIL.Loadkey IS NULL)
   BEGIN
--      SET @n_Continue = 3
      SET @n_Err = 20002
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Order without sorting Lane assigned. (isp_ValidateAssignLane)' 
      GOTO QUIT
   END

   IF EXISTS (SELECT 1
              FROM LOADPLANLANEDETAIL WITH (NOLOCK)
              LEFT JOIN #TMP_ORD TMP WITH (NOLOCK) ON (LOADPLANLANEDETAIL.MBOLKey = TMP.MBOLKey)
                                                   AND(LOADPLANLANEDETAIL.Loadkey = TMP.Loadkey) 
                                                   AND(LOADPLANLANEDETAIL.Loc     = TMP.Door)
                                                   
              WHERE LOADPLANLANEDETAIL.MBOLKey = @c_MBOLKey
              AND   LOADPLANLANEDETAIL.Loadkey = @c_Loadkey
              AND   LOADPLANLANEDETAIL.LocationCategory = 'PROC' 
              AND   TMP.Door IS NULL )
   BEGIN
--      SET @n_Continue = 3
      SET @n_Err = 20002
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Sorting Lane does not exist in Order. (isp_ValidateAssignLane)' 
      GOTO QUIT
   END

   IF NOT EXISTS (SELECT 1
              FROM LOADPLANLANEDETAIL WITH (NOLOCK)
              WHERE LOADPLANLANEDETAIL.MBOLKey = @c_MBOLKey
              AND   LOADPLANLANEDETAIL.Loadkey = @c_Loadkey
              AND   LOADPLANLANEDETAIL.LocationCategory = 'STAGING' )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 20003
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Despatch Lane does not exist in Order. (isp_ValidateAssignLane)' 
      GOTO QUIT
   END

   
   IF (SELECT COUNT(DISTINCT LOADPLANLANEDETAIL.LOC)
       FROM #TMP_ORD TMP 
       JOIN LOADPLANLANEDETAIL WITH (NOLOCK) ON  TMP.MBOLKey = LOADPLANLANEDETAIL.MBOLKey
                                             AND TMP.Loadkey = LOADPLANLANEDETAIL.Loadkey
                                             AND LOADPLANLANEDETAIL.LocationCategory = 'STAGING' 
       GROUP BY TMP.MBOLKey, TMP.LoadKey) <
      (SELECT COUNT(DISTINCT CODELKUP.Short)
       FROM #TMP_ORD TMP
       JOIN ORDERS WITH (NOLOCK) ON (TMP.Orderkey = ORDERS.Orderkey)
       JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'VFROUTE')
                                   AND(CODELKUP.Code     = ORDERS.C_City)
       GROUP BY TMP.MBOLKey, TMP.LoadKey)
   BEGIN
--      SET @n_Continue = 3
      SET @n_Err = 20004
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Despatch lane is < Route. (isp_ValidateAssignLane)' 
      GOTO QUIT
   END

   QUIT:

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
   END
   
END

GO