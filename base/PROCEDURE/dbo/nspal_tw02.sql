SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TW02                                         */
/* Creation Date: 24-Jun-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17333 - [TW] PEC_QKS_AllocateStrategy CR                */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/************************************************************************/
CREATE PROC [dbo].[nspAL_TW02]
     @c_lot                NVARCHAR(10)
   , @c_uom                NVARCHAR(10)
   , @c_HostWHCode         NVARCHAR(10)
   , @c_Facility           NVARCHAR(5)
   , @n_uombase            INT
   , @n_qtylefttofulfill   INT
   , @c_OtherParms         NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   

   DECLARE @c_OrderKey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Condition       NVARCHAR(2000)
         , @c_LoadPickMethod  NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLParm         NVARCHAR(4000) 
   
   SET @c_Condition = ''     
	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
      
      SELECT TOP 1 @c_LoadPickMethod = ISNULL(L.LoadPickMethod,''),
                   @c_Storerkey = O.Storerkey
      FROM ORDERS O (NOLOCK) 
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.OrderKey = LPD.OrderKey
      JOIN LOADPLAN L (NOLOCK) ON LPD.Loadkey = L.Loadkey
      WHERE O.Orderkey = @c_OrderKey 
   END
   
   IF ISNULL(@c_HostWHCode,'') <> ''
      SELECT @c_Condition = RTRIM(@c_Condition) + ' AND ISNULL(LOC.HostWhCode,'''') = N''' + RTRIM(ISNULL(@c_HostWHCode,'')) + ''' '
   ELSE
   BEGIN
      IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
                 WHERE CL.Storerkey = @c_Storerkey  
                 AND CL.Code = 'NOFILTERHWCODE'  
                 AND CL.Listname = 'PKCODECFG'  
                 AND ISNULL(CL.Short,'') = 'N') 
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND ISNULL(LOC.HostWhCode,'''') = N''' + RTRIM(ISNULL(@c_HostWHCode,'')) + ''' '		  	
      END					     
    END  

   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
              WHERE CL.Storerkey = @c_Storerkey
              AND CL.Code = 'ALLOCBYFLOOR'
              AND CL.Listname = 'PKCODECFG'
              AND ISNULL(CL.Short,'') <> 'N') AND @c_LoadPickMethod <> 'L-ORDER'  
   BEGIN      
      SET @c_SQL = N' DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                 +  ' SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID, ' + CHAR(13)
                 +  ' QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), ''1'' ' + CHAR(13)
                 +  ' FROM LOTxLOCxID (NOLOCK) ' + CHAR(13)
                 +  ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) ' + CHAR(13)
                 +  ' JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) ' + CHAR(13)
                 +  ' WHERE LOTxLOCxID.Lot = @c_lot ' + CHAR(13)
                 +  ' AND LOC.Locationflag <> ''HOLD'' ' + CHAR(13)
                 +  ' AND LOC.Locationflag <> ''DAMAGE'' ' + CHAR(13)
                 +  ' AND LOC.Status <> ''HOLD'' ' + CHAR(13)
                 +  ' AND LOC.Facility = @c_Facility '  + CHAR(13)
                 +  ' AND ID.STATUS <> ''HOLD'' ' + CHAR(13)
                 +    @c_Condition + CHAR(13)
                 +  ' ORDER BY LOC.Floor DESC, LOC.LogicalLocation, LOC.Loc '

      SET @c_SQLParm = N'@c_Facility   NVARCHAR(5)
                       , @c_lot        NVARCHAR(20) '

      EXEC sp_ExecuteSQL @c_SQL
                       , @c_SQLParm
                       , @c_Facility
                       , @c_lot
   END     
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.Loc
               ,LOTxLOCxID.ID
               ,QTYAVAILABLE = 0
               ,'1'
         FROM   LOTxLOCxID (NOLOCK)
         WHERE 1=2
   END 
END

GO