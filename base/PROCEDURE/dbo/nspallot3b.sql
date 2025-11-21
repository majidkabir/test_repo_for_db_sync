SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALLOT3B                                         */
/* Creation Date: 02-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Duplicated from mspALIDS06.											            */
/*          Have special handling with Lottable03.                      */
/* 			Use with Preallocate Strategy nspPRFEFO3						           	*/
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.1		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 07-Aug-2008  YokeBeen Modified for SQL2005 Compatible.               */
/* 12-Aug-2008  TLTING   Remove Some SET option                         */   
/* 11-Aug-2016  NJOW01   374687-Allowoverallocations storerconfig       */
/*                       control by facility                            */
/************************************************************************/

CREATE PROC [dbo].[nspALLOT3B]
            @c_lot NVARCHAR(10) ,
            @c_uom NVARCHAR(10) ,
            @c_HostWHCode NVARCHAR(10),
            @c_Facility NVARCHAR(5),
            @n_uombase int ,
            @n_qtylefttofulfill int, 
            @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN 
   SET CONCAT_NULL_YIELDS_NULL OFF
	SET NOCOUNT ON 
   DECLARE @b_debug int
   SET @b_debug = 0 

   -- Get OrderKey and line Number
   DECLARE @c_OrderKey              NVARCHAR(10) 
         , @c_OrderLineNumber       NVARCHAR(5) 
			, @c_Lottable03            NVARCHAR(18)   
         , @c_Conditions            NVARCHAR(510) 
         , @c_SQLStatement          NVARCHAR(3999) 	   	
         , @b_success               int 
         , @n_err                   int 
         , @c_errmsg                NVARCHAR(250) 
         , @c_StorerKey             NVARCHAR(15)
         , @c_AllowOverAllocations  NVARCHAR(1) 

   SET @c_Conditions = ''  
   SET @c_SQLStatement = ''
   SET @b_success = 0 
   SET @n_err = 0 
   SET @c_errmsg = '' 
   SET @c_StorerKey = '' 
   SET @c_AllowOverAllocations = '' 

   IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OtherParms)),'') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OtherParms)),''), 10)
      SELECT @c_OrderLineNumber = SUBSTRING(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OtherParms)),''), 11, 5)
   END

   -- Get Lottable03 
	SET @c_Lottable03 = ''
   IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderKey)),'') <> '' AND 
	   ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderLineNumber)),'') <> ''
   BEGIN
       SELECT @c_Lottable03 = ISNULL(Lottable03,'') 
            , @c_StorerKey = ISNULL(StorerKey,'') 
       FROM   ORDERDETAIL WITH (NOLOCK)
       WHERE  OrderKey = @c_OrderKey
		 AND    OrderLineNumber = @c_OrderLineNumber
   END

   IF @b_debug = 1 
      SELECT '@c_StorerKey/@c_OtherParms - ', @c_StorerKey, @c_OtherParms

   IF ISNULL(dbo.fnc_RTrim(@c_Lottable03),'') <> ''
   BEGIN
      SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' AND ( SKUxLOC.Locationtype <> ''PICK''' 
      SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' AND SKUxLOC.Locationtype <> ''CASE'' )' 
   END
   ELSE IF (ISNULL(dbo.fnc_RTrim(@c_Lottable03),'') = '') AND (ISNULL(dbo.fnc_RTrim(@c_uom),'') <> '1')
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspGetRight @c_Facility,  -- facility NJOW01
                          @c_StorerKey,  -- Storerkey
                          NULL,  -- Sku
                         'ALLOWOVERALLOCATIONS', -- Configkey
                          @b_success     output,
                          @c_AllowOverAllocations output, 
                          @n_err         output,
                          @c_errmsg      output
      
      IF @b_debug = 1 
         SELECT '@c_AllowOverAllocations - ', @c_AllowOverAllocations

      IF @b_success = 1
      BEGIN
         IF ISNULL(dbo.fnc_RTrim(@c_AllowOverAllocations),'') <> '1'
         BEGIN
            SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' AND ( SKUxLOC.Locationtype = ''PICK''' 
            SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' OR SKUxLOC.Locationtype = ''CASE'' )' 
         END
      END -- IF @b_success = 1
   END
   ELSE IF (ISNULL(dbo.fnc_RTrim(@c_Lottable03),'') = '') AND (ISNULL(dbo.fnc_RTrim(@c_uom),'') = '1')
   BEGIN
      SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' AND ( SKUxLOC.Locationtype <> ''PICK''' 
      SET @c_ConditionS = ISNULL(dbo.fnc_RTrim(@c_Conditions),'') + ' AND SKUxLOC.Locationtype <> ''CASE'' )' 
   END

	SELECT @c_SQLStatement = 
          ' DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' + 
          ' FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, ' + 
          ' QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), ''1'' ' + 
          ' FROM LOTxLOCxID WITH (NOLOCK) ' +  
          ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) ' +  
          ' JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND ' +  
          ' LOTxLOCxID.Sku = SKUxLOC.Sku AND LOTxLOCxID.Loc = SKUxLOC.Loc) ' +  
          ' JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.id = ID.id) ' +  
          ' WHERE LOTxLOCxID.Lot = N''' + ISNULL(dbo.fnc_RTrim(@c_lot),'') + '''' +  
          ' AND id.status = ''OK'' ' + 
          ' AND SKUxLOC.Locationtype <> ''OTHER'' ' + 
          ' AND LOC.Facility = N''' + ISNULL(dbo.fnc_RTrim(@c_Facility),'') + '''' +  
          ' AND LOC.Locationflag <> ''HOLD'' ' + 
          ' AND LOC.Locationflag <> ''DAMAGE'' ' + 
          ' AND LOC.Status <> ''HOLD'' ' + 
          ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 ' + 
            ISNULL(dbo.fnc_RTrim(@c_Conditions),'')  + 
          ' ORDER BY LogicalLocation, LOC.LOC '    

	EXEC(@c_SQLStatement)
END



GO