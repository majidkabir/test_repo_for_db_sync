SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_AssignSortLaneToOrd                             */  
/* Creation Date: 25-JAN-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#265537 - VFCDC-Assign Sort and Dispatch Lane             */  
/*                                                                       */  
/* Called By: Call from RCM Function 'Sorting Lane Calculation'          */
/*            at Lane Assignment Screen                                  */  
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

CREATE PROC [dbo].[isp_AssignSortLaneToOrd]
      @c_Loadkey  NVARCHAR(10)
   ,  @b_Success  INT            OUTPUT
   ,  @n_Err      INT            OUTPUT
   ,  @c_ErrMsg   NVARCHAR(255)   OUTPUT         
AS  
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @n_Continue        INT

   DECLARE @c_ExecStatement   NVARCHAR(4000)
         , @c_ExecArguements  NVARCHAR(4000)

   DECLARE @c_Orderkey        NVARCHAR(10)

   DECLARE @c_Operator        NVARCHAR(5)
         , @c_Sorting         NVARCHAR(5)
         , @c_AssignLane      NVARCHAR(10)
         , @c_Loc             NVARCHAR(10)
         , @c_LP_LaneNumber   NVARCHAR(5)
         , @c_SeqNo           NVARCHAR(5)

   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_ErrMsg        = ''
     
   SET @n_Continue      = 1
    
   SET @c_ExecStatement = ''
   SET @c_ExecArguements= ''

   SET @c_Orderkey      = ''

   SET @c_Operator      = '>'
   SET @c_Sorting       = 'ASC'  
   SET @c_AssignLane    = ''
   SET @c_Loc           = ''
   SET @c_LP_LaneNumber = ''
   SET @c_SeqNo         = ''  

   -- Load does not have assign sort lane.
   IF NOT EXISTS (SELECT 1
                  FROM LOADPLANLANEDETAIL WITH (NOLOCK)
                  WHERE Loadkey = @c_LoadKey
                  AND LocationCategory = 'PROC')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 20001
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Load does not assign with Sort Lane. (isp_AssignSortLaneToOrd)' 
      GOTO QUIT
   END

   -- There is SO has started packing.
   IF EXISTS (SELECT 1 
              FROM LOADPLANDETAIL WITH (NOLOCK)
              WHERE LoadKey = @c_LoadKey
              AND  EXISTS (SELECT 1
                           FROM PACKHEADER WITH (NOLOCK)
                           WHERE LoadKey = LOADPLANDETAIL.Loadkey
                           AND   Orderkey= LOADPLANDETAIL.Orderkey))
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 20002
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Order has started packing. (isp_AssignSortLaneToOrd)' 
      GOTO QUIT
   END

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT ORDERS.Orderkey
   FROM LOADPLANDETAIL WITH (NOLOCK) 
   JOIN ORDERS      WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                  AND(ORDERDETAIL.Sku = SKU.Sku)
   WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey
   GROUP BY ORDERS.Orderkey
   ORDER BY ISNULL(SUM(SKU.StdCube * (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked)),0)

   OPEN CUR_ORD      
         
   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey  
   WHILE @@FETCH_STATUS <> -1      
   BEGIN 
      SET @c_AssignLane = ''
      SET @c_LP_LaneNumber = ''
      SET @c_ExecStatement = N'SELECT TOP 1 @c_AssignLane = ISNULL(RTRIM(Loc),'''')'
                           + '      , @c_LP_LaneNumber = ISNULL(RTRIM(LP_LaneNumber),'''')'
                           + ' FROM LOADPLANLANEDETAIL WITH (NOLOCK) '
                           + ' WHERE Loadkey = @c_LoadKey'
                           + ' AND LocationCategory = ''PROC'''
                           + ' AND LP_LaneNumber ' + @c_Operator + ' @c_SeqNo'   
                           + ' ORDER BY LP_LaneNumber ' + @c_Sorting 

      SET @c_ExecArguements= N'@c_LoadKey       NVARCHAR(10)' 
                           + ',@c_SeqNo         NVARCHAR(5) '
                           + ',@c_AssignLane    NVARCHAR(10) OUTPUT'
                           + ',@c_LP_LaneNumber NVARCHAR(5)  OUTPUT'  

      EXEC sp_ExecuteSQL @c_ExecStatement
                        ,@c_ExecArguements
                        ,@c_LoadKey
                        ,@c_SeqNo
                        ,@c_AssignLane    OUTPUT
                        ,@c_LP_LaneNumber OUTPUT

      IF @c_AssignLane = ''
      BEGIN
         IF @c_Sorting = 'ASC' 
         BEGIN
            SET @c_Operator= '<'
            SET @c_Sorting = 'DESC'
         END
         ELSE
         BEGIN
            SET @c_Operator= '>'
            SET @c_Sorting = 'ASC'
         END
      END 
      ELSE
      BEGIN
         SET @c_Loc = @c_AssignLane
         SET @c_SeqNo = @c_LP_LaneNumber
      END

      UPDATE ORDERS WITH (ROWLOCK)
      SET Door = @c_Loc
         ,EditWho  = SUSER_NAME()
         ,EditDate = GETDATE()
         ,Trafficcop = NULL
      WHERE Orderkey = @c_Orderkey
   
      IF @@Error <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 20003
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Assign Sort Lane to Order fail. (isp_AssignSortLaneToOrd)' 
         GOTO QUIT
      END  

      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey 
   END

   QUIT:

   IF CURSOR_STATUS('LOCAL', 'CUR_ORD') = 1
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
   END
END

GO