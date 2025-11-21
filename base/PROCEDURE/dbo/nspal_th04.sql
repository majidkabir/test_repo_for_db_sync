SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TH04                                         */
/* Creation Date:16-AUG-2019                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspAL_TH04]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   --@c_sectionkey NVARCHAR(3),
   --@c_oskey NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN 
   SET NOCOUNT ON 

   DECLARE @c_Condition       NVARCHAR(4000),     
           @c_SQLStatement    NVARCHAR(3999), 
           @c_OrderBy         NVARCHAR(2000),
           @c_Condition1      NVARCHAR(4000),
           @c_Orderkey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ID              NVARCHAR(18),
           @c_Consigneekey    NVARCHAR(15),
           @c_Secondary       NVARCHAR(15),  
           @c_ExecStatements  NVARCHAR(MAX),
           @c_ExecArguments   NVARCHAR(4000)   
    
  SET @c_Condition = ''

   IF LEN(@c_OtherParms) > 0 
   BEGIN
        SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
        SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
                 
        SELECT TOP 1 @c_ID = OD.ID,
                     @c_Consigneekey = O.Consigneekey,
                     @c_Secondary = S.Secondary       
        FROM ORDERS O (NOLOCK) 
        JOIN ORDERDETAIL OD ON O.Orderkey = OD.Orderkey
        LEFT JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
        WHERE O.Orderkey = @c_Orderkey
        AND OD.OrderLineNumber = @c_OrderLineNumber                 
   END

   IF @c_Secondary = 'RTV'
   BEGIN
    SET @c_Condition = ' AND Loc.Pickzone = ''NIKE-M3'' '
   END

    SELECT @c_OrderBy = 'ORDER BY LogicalLocation, LOC.LOC '
   

   SELECT @c_SQLStatement =  " DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                             " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                             " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),'1' " +
                             " FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (nolock)" +
                             " WHERE LOTxLOCxID.Lot = @c_lot " +
                             " AND LOTxLOCxID.Loc = LOC.LOC" +
                             " AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey" +
                             " AND LOTxLOCxID.Sku = SKUxLOC.Sku" +
                             " AND LOTxLOCxID.Loc = SKUxLOC.Loc" +
                             " AND LOTxLOCxID.id = ID.id" +
                             " AND id.status = 'OK'  " +
                             " AND SKUxLOC.Locationtype <> 'OTHER'  " +
                             " AND LOC.Facility = @c_Facility  " +
                             " AND LOC.Locationflag <>'HOLD' " +
                             " AND LOC.Locationflag <> 'DAMAGE' " +
                             " AND LOC.Status <> 'HOLD' " +
                             " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 "  -- SOS38045



    SELECT @c_ExecStatements = @c_SQLStatement + CHAR(13) + @c_Condition  + CHAR(13) + @c_OrderBy

    SET @c_ExecArguments = N'@c_lot       NVARCHAR(20)'    
                        + ', @c_Facility  NVARCHAR(20) '    
                                      
   EXEC sp_ExecuteSql     @c_ExecStatements     
                        , @c_ExecArguments    
                        , @c_lot    
                        , @c_Facility    
   
END

GO